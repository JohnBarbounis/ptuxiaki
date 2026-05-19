import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OliveManagerApp());
}

class OliveManagerApp extends StatelessWidget {
  const OliveManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Διαχείριση Ελαιώνα',
      debugShowCheckedModeBanner: false, // Αφαιρεί το "DEBUG" πάνω δεξιά
      theme: ThemeData(
        // Επιλέγουμε ένα πράσινο θέμα που ταιριάζει με την ελαιοπαραγωγή
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(), // Η αρχική μας οθόνη
    );
  }
}

