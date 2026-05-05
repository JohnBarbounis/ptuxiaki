// Αρχείο: lib/services/agronomist_service.dart
import 'package:flutter/material.dart';
import '../utils/text_formatting.dart';

class AgronomistService {
  // ✅ Use centralized Greek month name function
  static String getMonthNameInGreek(int month) {
    return TextFormatting.getGreekMonthName(month);
  }

  // Επιστρέφει τη Γεωπονική Συμβουλή ανάλογα με τον τρέχοντα μήνα
  static Map<String, dynamic> getMonthlyAdvice() {
    final int currentMonth = DateTime.now().month;

    switch (currentMonth) {
      case 1: // Ιανουάριος
      case 2: // Φεβρουάριος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Λήθαργος & Χειμερινό Κλάδεμα',
          'advice':
              'Τα δέντρα βρίσκονται σε λήθαργο. Ιδανική περίοδος για χειμερινό κλάδεμα και εφαρμογή της βασικής λίπανσης στο έδαφος.',
          'icon': Icons.content_cut,
          'color': Colors.blueGrey,
        };
      case 3: // Μάρτιος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Έκπτυξη Οφθαλμών',
          'advice':
              'Ξεκινά η νέα βλάστηση. Προσοχή σε μυκητολογικές ασθένειες (π.χ. Κυκλοκόνιο) αν υπάρχει αυξημένη υγρασία. Προτείνεται ψεκασμός με χαλκό.',
          'icon': Icons.grass,
          'color': Colors.green[600],
        };
      case 4: // Απρίλιος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Σχηματισμός Ανθέων',
          'advice':
              'Τα άνθη σχηματίζονται. Ένας διαφυλλικός ψεκασμός με Βόριο (B) τώρα, θα βοηθήσει σημαντικά στην καρπόδεση τον επόμενο μήνα.',
          'icon': Icons.local_florist,
          'color': Colors.pink[400],
        };
      case 5: // Μάιος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Άνθηση & Καρπόδεση',
          'advice':
              'Η πιο κρίσιμη περίοδος! ΑΠΑΓΟΡΕΥΕΤΑΙ αυστηρά η χρήση εντομοκτόνων που βλάπτουν τις μέλισσες. Περιορίστε τις άσκοπες εργασίες.',
          'icon': Icons.hive,
          'color': Colors.amber[700],
        };
      case 6: // Ιούνιος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Ανάπτυξη Καρπού',
          'advice':
              'Ο καρπός μεγαλώνει. Ξεκινήστε την παρακολούθηση για τη γενιά του Πυρηνοτρήτη. Αν έχετε αρδευτικό, ξεκινήστε τα ποτίσματα.',
          'icon': Icons.water_drop,
          'color': Colors.lightBlue,
        };
      case 7: // Ιούλιος
      case 8: // Αύγουστος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Σκλήρυνση Πυρήνα & Ελαιογένεση',
          'advice':
              'Το κουκούτσι σκληραίνει και το δέντρο φτιάχνει το λάδι. Τεράστια ανάγκη για νερό! Προσοχή στις δακοσυλλήψεις αν πέσει η θερμοκρασία.',
          'icon': Icons.wb_sunny,
          'color': Colors.orange[700],
        };
      case 9: // Σεπτέμβριος
      case 10: // Οκτώβριος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Ωρίμανση & Αλλαγή Χρώματος',
          'advice':
              'Ο καρπός αλλάζει χρώμα. Υψηλός κίνδυνος για δάκο λόγω φθινοπωρινής δροσιάς. Συνεχίστε τους ελέγχους στις παγίδες σας.',
          'icon': Icons.bug_report,
          'color': Colors.deepOrange,
        };
      case 11: // Νοέμβριος
      case 12: // Δεκέμβριος
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Συγκομιδή',
          'advice':
              'Περίοδος ελαιοσυλλογής! Μετά το μάζεμα, προτείνεται άμεσα ένας ψεκασμός με χαλκό για να επουλωθούν οι πληγές στα κλαδιά.',
          'icon': Icons.opacity,
          'color': Colors.green[800],
        };
      default:
        return {
          'month': getMonthNameInGreek(currentMonth),
          'stage': 'Γενική Φροντίδα',
          'advice': 'Παρακολουθείτε τακτικά τον ελαιώνα σας.',
          'icon': Icons.park,
          'color': Colors.green,
        };
    }
  }
}
