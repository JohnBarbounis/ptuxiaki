import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart'; // ΝΕΟ: Για το Excel
import 'package:path_provider/path_provider.dart'; // ΝΕΟ: Για προσωρινούς φακέλους
import '../services/database_helper.dart'; // ΝΕΟ: Για να διαβάζουμε τα δεδομένα

class BackupService {
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted)
        manageStatus = await Permission.manageExternalStorage.request();

      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted)
        storageStatus = await Permission.storage.request();

      return manageStatus.isGranted || storageStatus.isGranted;
    }
    return true;
  }

  // --- 1. ΕΞΑΓΩΓΗ ΒΑΣΗΣ (Drive, Email) ---
  static Future<void> exportDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'olive_manager.db');
      if (await File(path).exists()) {
        await Share.shareXFiles([
          XFile(path),
        ], text: 'Αντίγραφο Ασφαλείας - Olive Manager');
      }
    } catch (e) {
      print(e);
    }
  }

  // --- 2. ΤΟΠΙΚΗ ΑΠΟΘΗΚΕΥΣΗ ΒΑΣΗΣ ---
  static Future<bool> saveDatabaseLocally() async {
    try {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) return false;

      final dbPath = await getDatabasesPath();
      File dbFile = File(join(dbPath, 'olive_manager.db'));

      if (await dbFile.exists()) {
        String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Επιλέξτε φάκελο',
        );
        if (selectedDirectory != null) {
          String targetPath = join(
            selectedDirectory,
            'olive_manager_backup_${DateTime.now().day}_${DateTime.now().month}.db',
          );
          await dbFile.copy(targetPath);
          return true;
        }
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  // --- 3. ΕΙΣΑΓΩΓΗ ΒΑΣΗΣ (RESTORE) ---
  static Future<bool> importDatabase() async {
    try {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) return false;

      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result != null) {
        final targetPath = join(await getDatabasesPath(), 'olive_manager.db');
        await File(result.files.single.path!).copy(targetPath);
        return true;
      }
    } catch (e) {
      print(e);
    }
    return false;
  }

  // --- 4. ΕΞΑΓΩΓΗ ΣΕ EXCEL (.xlsx) ΜΕ ΠΛΗΡΗ ΣΤΑΤΙΣΤΙΚΑ ---
  static Future<bool> exportToExcel() async {
    try {
      // 1. Δημιουργία εικονικού Excel
      var excel = Excel.createExcel();
      final db = await DatabaseHelper.instance.database;

      // 2. Ανάκτηση δεδομένων
      final groves = await db.query('groves');
      final tasks = await db.query('tasks');
      final harvests = await db.query('harvests');

      // ==========================================
      // ΦΥΛΛΟ 1: ΣΥΓΚΕΝΤΡΩΤΙΚΑ ΧΩΡΑΦΙΩΝ (Πλήρης Αναφορά)
      // ==========================================
      excel.rename('Sheet1', 'Χωράφια - Στατιστικά');
      Sheet sheetGroves = excel['Χωράφια - Στατιστικά'];

      // Οι επικεφαλίδες του αγρότη
      sheetGroves.appendRow([
        TextCellValue('Όνομα Χωραφιού'),
        TextCellValue('Στρέμματα'),
        TextCellValue('Τοποθεσία'),
        TextCellValue('Συνολικά Έξοδα (€)'),
        TextCellValue('Συνολικά Έσοδα (€)'),
        TextCellValue('Καθαρό Κέρδος (€)'),
        TextCellValue('Συνολικά Λίτρα Λαδιού'),
        TextCellValue('Συνολικά Κιλά Ελιάς'),
        TextCellValue('Απόδοση (Λίτρα ανά Στρέμμα)'),
      ]);

      // Υπολογισμός στατιστικών για ΚΑΘΕ χωράφι ξεχωριστά
      for (var g in groves) {
        String groveId = g['id'].toString();
        String name = g['name'].toString();
        double area = (g['area'] as num).toDouble();
        String location = (g['lat'] != null && g['lng'] != null)
            ? '${g['lat']}, ${g['lng']}'
            : 'Μη διαθέσιμη';

        // Α. Έξοδα Χωραφιού
        double totalCost = 0.0;
        final groveTasks = await db.query(
          'tasks',
          where: 'groveId = ?',
          whereArgs: [groveId],
        );
        for (var t in groveTasks) totalCost += (t['cost'] as num).toDouble();

        // Β. Έσοδα και Παραγωγή Χωραφιού
        double totalOil = 0.0;
        double totalOlives = 0.0;
        double totalRevenue = 0.0;
        final groveHarvests = await db.query(
          'harvests',
          where: 'groveId = ?',
          whereArgs: [groveId],
        );
        for (var h in groveHarvests) {
          double oil = (h['oilVolume'] as num).toDouble();
          double price = (h['pricePerUnit'] as num).toDouble();
          totalOil += oil;
          totalOlives += (h['olivesWeight'] as num).toDouble();
          totalRevenue += (oil * price);
        }

        // Γ. Δείκτες (Κέρδος & Απόδοση)
        double netProfit = totalRevenue - totalCost;
        double yieldPerStremma = area > 0 ? (totalOil / area) : 0.0;

        // Εγγραφή της γραμμής στο Excel
        sheetGroves.appendRow([
          TextCellValue(name),
          DoubleCellValue(area),
          TextCellValue(location),
          DoubleCellValue(totalCost),
          DoubleCellValue(totalRevenue),
          DoubleCellValue(netProfit),
          DoubleCellValue(totalOil),
          DoubleCellValue(totalOlives),
          DoubleCellValue(
            double.parse(yieldPerStremma.toStringAsFixed(2)),
          ), // Στρογγυλοποίηση στα 2 δεκαδικά
        ]);
      }

      // ==========================================
      // ΦΥΛΛΟ 2: ΑΝΑΛΥΤΙΚΕΣ ΕΡΓΑΣΙΕΣ
      // ==========================================
      Sheet sheetTasks = excel['Ιστορικό Εργασιών'];
      sheetTasks.appendRow([
        TextCellValue('ID Χωραφιού'),
        TextCellValue('Τίτλος Εργασίας'),
        TextCellValue('Τύπος'),
        TextCellValue('Ημερομηνία'),
        TextCellValue('Κόστος (€)'),
      ]);

      for (var t in tasks) {
        sheetTasks.appendRow([
          TextCellValue(t['groveId'].toString()),
          TextCellValue(t['title'].toString()),
          TextCellValue(t['type'].toString()),
          TextCellValue(
            t['date'].toString().split('T')[0],
          ), // Κρατάμε μόνο την ημερομηνία (π.χ. 2024-05-12)
          DoubleCellValue(t['cost'] as double),
        ]);
      }

      // ==========================================
      // ΦΥΛΛΟ 3: ΑΝΑΛΥΤΙΚΕΣ ΣΥΓΚΟΜΙΔΕΣ
      // ==========================================
      Sheet sheetHarvests = excel['Ιστορικό Συγκομιδών'];
      sheetHarvests.appendRow([
        TextCellValue('ID Χωραφιού'),
        TextCellValue('Ημερομηνία'),
        TextCellValue('Λίτρα Λαδιού'),
        TextCellValue('Κιλά Ελιάς'),
        TextCellValue('Οξύτητα'),
        TextCellValue('Τιμή Πώλησης (€/L)'),
      ]);

      for (var h in harvests) {
        sheetHarvests.appendRow([
          TextCellValue(h['groveId'].toString()),
          TextCellValue(h['date'].toString().split('T')[0]),
          DoubleCellValue(h['oilVolume'] as double),
          DoubleCellValue(h['olivesWeight'] as double),
          DoubleCellValue(h['acidity'] as double),
          DoubleCellValue(h['pricePerUnit'] as double),
        ]);
      }

      // 3. Αποθήκευση και Κοινοποίηση
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final path = join(
        directory.path,
        'OliveManager_Report_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.xlsx',
      );

      File(path).writeAsBytesSync(fileBytes!, flush: true);

      await Share.shareXFiles([
        XFile(path),
      ], text: 'Οικονομική και Γεωπονική Αναφορά (Excel)');
      return true;
    } catch (e) {
      print("Σφάλμα εξαγωγής Excel: $e");
      return false;
    }
  }
}
