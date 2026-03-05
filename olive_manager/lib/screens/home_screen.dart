// Αρχείο: lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../models/olive_grove.dart';
import 'add_grove_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Εδώ θα αποθηκεύουμε προσωρινά (στη μνήμη) τα χωράφια μας
  final List<OliveGrove> myGroves = [];

  // Συνάρτηση που ανοίγει την οθόνη προσθήκης
  Future<void> _navigateToAddGrove() async {
    final result = await Navigator.of(context).push<OliveGrove>(
      MaterialPageRoute(builder: (context) => const AddGroveScreen()),
    );

    // Αν ο χρήστης πάτησε "Αποθήκευση" (δεν γύρισε πίσω απλά)
    if (result != null) {
      setState(() {
        myGroves.add(result); // Βάζουμε το νέο χωράφι στη λίστα μας
      });
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
      // Αν η λίστα είναι άδεια δείχνουμε κείμενο, αλλιώς φτιάχνουμε μια λίστα με κάρτες
      body: myGroves.isEmpty
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
                      // Εδώ θα ανοίγουμε τις λεπτομέρειες του χωραφιού αργότερα!
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
