// lib/utils/app_validators.dart
// Centralized validation utilities for form inputs

class AppValidators {
  // Validation para Area (Stremmata)
  static String? validateArea(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    try {
      final area = double.parse(value.replaceAll(',', '.'));
      if (area <= 0) {
        return 'Πρέπει να είναι θετικό νούμερο';
      }
      if (area > 10000) {
        return 'Πολύ μεγάλο εμβαδόν (>10,000 Στρέμματα)';
      }
      return null;
    } catch (e) {
      return 'Μη έγκυρος αριθμός (χρησιμοποιήστε . ή ,)';
    }
  }

  // Validation para Tree Count
  static String? validateTreeCount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    try {
      final trees = int.parse(value);
      if (trees < 0) {
        return 'Δεν μπορεί να είναι αρνητικό';
      }
      if (trees == 0) {
        return 'Τουλάχιστον 1 δέντρο';
      }
      if (trees > 100000) {
        return 'Πολύ μεγάλος αριθμός (>100,000)';
      }
      return null;
    } catch (e) {
      return 'Μόνο ακέραιοι αριθμοί';
    }
  }

  // Validation para Cost/Price (€)
  static String? validateCost(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    try {
      final cost = double.parse(value.replaceAll(',', '.'));
      if (cost < 0) {
        return 'Δεν μπορεί να είναι αρνητικό';
      }
      if (cost > 1000000) {
        return 'Ασυνήθιστα μεγάλο κόστος';
      }
      return null;
    } catch (e) {
      return 'Μη έγκυρος αριθμός';
    }
  }

  // Validation para Grove Name
  static String? validateGroveName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    if (value.length < 2) {
      return 'Τουλάχιστον 2 χαρακτήρες';
    }
    if (value.length > 100) {
      return 'Μέχρι 100 χαρακτήρες';
    }
    return null;
  }

  // Validation para Task Title
  static String? validateTaskTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    if (value.length < 3) {
      return 'Τουλάχιστον 3 χαρακτήρες';
    }
    if (value.length > 150) {
      return 'Μέχρι 150 χαρακτήρες';
    }
    return null;
  }

  // Validation para Oil Volume
  static String? validateOilVolume(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    try {
      final volume = double.parse(value.replaceAll(',', '.'));
      if (volume <= 0) {
        return 'Πρέπει να είναι θετικό';
      }
      if (volume > 100000) {
        return 'Ασυνήθιστα μεγάλη ποσότητα λαδιού';
      }
      return null;
    } catch (e) {
      return 'Μη έγκυρος αριθμός';
    }
  }

  // Validation para Acidity
  static String? validateAcidity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Υποχρεωτικό πεδίο';
    }
    try {
      final acidity = double.parse(value.replaceAll(',', '.'));
      if (acidity < 0) {
        return 'Δεν μπορεί να είναι αρνητικό';
      }
      if (acidity > 10) {
        return 'Ασυνήθιστα υψηλή οξύτητα';
      }
      return null;
    } catch (e) {
      return 'Μη έγκυρος αριθμός';
    }
  }
}
