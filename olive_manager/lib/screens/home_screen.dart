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
                return Dismissible(
                  // Το κλειδί πρέπει να είναι μοναδικό για κάθε στοιχείο
                  key: Key(grove.id),

                  // Κατεύθυνση: από δεξιά προς τα αριστερά
                  direction: DismissDirection.endToStart,

                  // Το κόκκινο φόντο με τον κάδο
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  // Παράθυρο επιβεβαίωσης με προειδοποίηση!
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text("Διαγραφή Χωραφιού"),
                          content: const Text(
                            "Είστε σίγουροι; Η διαγραφή του χωραφιού θα διαγράψει οριστικά ΚΑΙ ΟΛΕΣ τις εργασίες που έχετε καταχωρήσει σε αυτό!",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("ΑΚΥΡΩΣΗ"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
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

                  // Αν ο χρήστης πατήσει Διαγραφή
                  onDismissed: (direction) async {
                    // 1. Διαγραφή από τη βάση δεδομένων
                    await DatabaseHelper.instance.deleteGrove(grove.id);

                    // 2. Ανανέωση της λίστας
                    _refreshGroves();

                    // 3. Εμφάνιση μηνύματος
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Το χωράφι και οι εργασίες του διαγράφηκαν',
                        ),
                      ),
                    );
                  },

                  // Η κάρτα του χωραφιού μας όπως ήταν
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${grove.treeCount} δέντρα'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                GroveDetailsScreen(grove: grove),
                          ),
                        );
                      },
                    ),
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
