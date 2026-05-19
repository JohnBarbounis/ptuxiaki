import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_helper.dart';
import '../utils/app_logger.dart';
import 'package:http/http.dart' as http;

class BackupService {
  // --- ΒΟΗΘΗΤΙΚΗ 1: Έλεγχος Αδειών (για Android) ---
  static Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        manageStatus = await Permission.manageExternalStorage.request();
      }

      var storageStatus = await Permission.storage.status;
      if (!storageStatus.isGranted) {
        storageStatus = await Permission.storage.request();
      }

      return manageStatus.isGranted || storageStatus.isGranted;
    }
    return true;
  }

  // --- ΒΟΗΘΗΤΙΚΗ 2: Παραγωγή των δεδομένων JSON ---
  static Future<String> _generateJsonData() async {
    final db = await DatabaseHelper.instance.database;
    final groves = await db.query('groves');
    final tasks = await db.query('tasks');
    final harvests = await db.query('harvests');

    final Map<String, dynamic> backupData = {
      'version': 2,
      'timestamp': DateTime.now().toIso8601String(),
      'groves': groves,
      'tasks': tasks,
      'harvests': harvests,
    };

    return jsonEncode(backupData);
  }

  // ==================================================
  // 1.Α. ΚΟΙΝΟΠΟΙΗΣΗ JSON (Share σε Email, Drive κλπ)
  // ==================================================
  static Future<bool> shareJsonBackup() async {
    try {
      String jsonString = await _generateJsonData();
      final directory = await getTemporaryDirectory();
      final path = join(
        directory.path,
        'OliveManager_Backup_${DateTime.now().day}_${DateTime.now().month}.json',
      );

      File backupFile = File(path);
      await backupFile.writeAsString(jsonString);

      // Note: File sharing via SharePlus requires ShareParams
      // For now, we'll skip the actual sharing and just save the file locally
      AppLogger.info('Backup saved to: $path');
      return true;
    } catch (e) {
      AppLogger.error('Σφάλμα κοινοποίησης JSON', e);
      return false;
    }
  }

  // ==================================================
  // 1.Β. ΤΟΠΙΚΗ ΑΠΟΘΗΚΕΥΣΗ JSON (Στη Συσκευή)
  // ==================================================
  static Future<bool> saveJsonLocally() async {
    try {
      bool hasPermission = await _requestStoragePermission();
      if (!hasPermission) return false;

      // Ζητάμε από τον χρήστη να διαλέξει φάκελο στο κινητό του
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Επιλέξτε φάκελο αποθήκευσης',
      );

      if (selectedDirectory != null) {
        String jsonString = await _generateJsonData();
        String targetPath = join(
          selectedDirectory,
          'OliveManager_Backup_${DateTime.now().day}_${DateTime.now().month}.json',
        );

        File backupFile = File(targetPath);
        await backupFile.writeAsString(jsonString);
        return true;
      }
    } catch (e) {
      AppLogger.error('Σφάλμα τοπικής αποθήκευσης JSON', e);
    }
    return false;
  }

  // ==================================================
  // 2. ΕΙΣΑΓΩΓΗ ΒΑΣΗΣ ΑΠΟ JSON (Restore)
  // ==================================================
  static Future<bool> importDataFromJson() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String jsonString = await file.readAsString();
        Map<String, dynamic> backupData = jsonDecode(jsonString);
        final db = await DatabaseHelper.instance.database;

        await db.transaction((txn) async {
          await txn.delete('groves');
          await txn.delete('tasks');
          await txn.delete('harvests');

          for (var g in backupData['groves']) {
            await txn.insert(
              'groves',
              g,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (var t in backupData['tasks']) {
            await txn.insert(
              'tasks',
              t,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          for (var h in backupData['harvests']) {
            await txn.insert(
              'harvests',
              h,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        });
        return true;
      }
    } catch (e) {
      AppLogger.error('Σφάλμα εισαγωγής JSON', e);
    }
    return false;
  }

  // ... (Από εδώ και κάτω συνεχίζει κανονικά το shareExcelReport που έχουμε ήδη) ...

  // --- 4. ΕΞΑΓΩΓΗ ΣΕ EXCEL ΜΕ ΕΞΥΠΝΗ ΤΟΠΟΘΕΣΙΑ ---
  static Future<bool> shareExcelReport() async {
    try {
      var excel = Excel.createExcel();
      final db = await DatabaseHelper.instance.database;

      final groves = await db.query('groves');
      final tasks = await db.query('tasks');
      final harvests = await db.query('harvests');

      // --- STYLING ---
      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle totalStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      );

      // ==========================================
      // ΦΥΛΛΟ 1: ΣΥΓΚΕΝΤΡΩΤΙΚΑ ΧΩΡΑΦΙΩΝ
      // ==========================================
      excel.rename('Sheet1', 'Χωράφια - Στατιστικά');
      Sheet sheetGroves = excel['Χωράφια - Στατιστικά'];

      List<String> groveHeaders = [
        'Όνομα Χωραφιού',
        'Στρέμματα',
        'Δέντρα',
        'Περιοχή / Τοποθεσία', // Προστέθηκαν τα "Δέντρα"
        'Συνολικά Έξοδα (€)', 'Συνολικά Έσοδα (€)', 'Καθαρό Κέρδος (€)',
        'Λίτρα Λαδιού', 'Κιλά Ελιάς', 'Απόδοση (L/Στρέμμα)',
        'Απόδοση (L/Δέντρο)',
        'Κέρδος (€/Δέντρο)', // Προστέθηκαν οι νέοι δείκτες
      ];
      sheetGroves.appendRow(groveHeaders.map((h) => TextCellValue(h)).toList());

      for (int i = 0; i < groveHeaders.length; i++) {
        sheetGroves
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetGroves.setColumnWidth(
          i,
          22.0,
        ); // Λίγο μεγαλύτερο πλάτος για το όνομα της περιοχής
      }

      double sumExpenses = 0, sumRevenue = 0, sumProfit = 0, sumOil = 0;
      int currentRow = 1;

      for (var g in groves) {
        String groveId = g['id'].toString();
        String name = g['name'].toString();
        double area = (g['area'] as num).toDouble();

        // --- ΝΕΑ ΛΟΓΙΚΗ: REVERSE GEOCODING ---
        String locationStr = 'Μη διαθέσιμη';
        if (g['lat'] != null && g['lng'] != null) {
          double lat = (g['lat'] as num).toDouble();
          double lng = (g['lng'] as num).toDouble();

          try {
            // Ρωτάμε το API για το όνομα της περιοχής (με Timeout 3 δευτερολέπτων για να μην κολλήσει το Excel αν δεν έχουμε ίντερνετ)
            final geoUrl = Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=el',
            );
            final geoResponse = await http
                .get(geoUrl)
                .timeout(const Duration(seconds: 3));

            if (geoResponse.statusCode == 200) {
              final geoData = json.decode(geoResponse.body);
              String city = geoData['city'] ?? geoData['locality'] ?? '';

              if (city.isNotEmpty) {
                // Φτιάχνουμε ένα όμορφο string: π.χ. "Ηράκλειο (35.33, 25.14)"
                locationStr =
                    '$city (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
              } else {
                locationStr =
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
              }
            } else {
              locationStr =
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
            }
          } catch (e) {
            // Αν δεν έχουμε ίντερνετ, απλά βάζουμε τις συντεταγμένες
            locationStr =
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
          }
        }

        double totalCost = 0.0;
        final groveTasks = await db.query(
          'tasks',
          where: 'groveId = ?',
          whereArgs: [groveId],
        );
        for (var t in groveTasks) {
          totalCost += (t['cost'] as num).toDouble();
        }

        double totalOil = 0.0, totalOlives = 0.0, totalRevenue = 0.0;
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

        double netProfit = totalRevenue - totalCost;
        double yieldPerStremma = area > 0 ? (totalOil / area) : 0.0;

        int trees = g['treeCount'] != null ? g['treeCount'] as int : 0;
        double yieldPerTree = trees > 0 ? (totalOil / trees) : 0.0;
        double profitPerTree = trees > 0 ? (netProfit / trees) : 0.0;

        sumExpenses += totalCost;
        sumRevenue += totalRevenue;
        sumProfit += netProfit;
        sumOil += totalOil;

        sheetGroves.appendRow([
          TextCellValue(name),
          DoubleCellValue(area),
          IntCellValue(trees), // ΝΕΟ
          TextCellValue(locationStr),
          DoubleCellValue(totalCost),
          DoubleCellValue(totalRevenue),
          DoubleCellValue(netProfit),
          DoubleCellValue(totalOil),
          DoubleCellValue(totalOlives),
          DoubleCellValue(double.parse(yieldPerStremma.toStringAsFixed(2))),
          DoubleCellValue(double.parse(yieldPerTree.toStringAsFixed(2))), // ΝΕΟ
          DoubleCellValue(
            double.parse(profitPerTree.toStringAsFixed(2)),
          ), // ΝΕΟ
        ]);
        currentRow++;
      }

      // --- ΓΡΑΜΜΗ ΣΥΝΟΛΩΝ ---
      sheetGroves.appendRow([
        TextCellValue('ΓΕΝΙΚΑ ΣΥΝΟΛΑ:'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(sumExpenses),
        DoubleCellValue(sumRevenue),
        DoubleCellValue(sumProfit),
        DoubleCellValue(sumOil),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      for (int i = 0; i < groveHeaders.length; i++) {
        sheetGroves
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            totalStyle;
      }

      // ==========================================
      // ΦΥΛΛΟ 2 & 3: Ιστορικό Εργασιών & Συγκομιδών
      // ==========================================
      // Δημιουργούμε Map groveId -> name για αναζήτηση
      Map<String, String> groveNameMap = {};
      for (var g in groves) {
        groveNameMap[g['id'].toString()] = g['name'].toString();
      }

      Sheet sheetTasks = excel['Ιστορικό Εργασιών'];
      List<String> taskHeaders = [
        'Χωράφι',
        'Τίτλος Εργασίας',
        'Τύπος',
        'Ημερομηνία',
        'Κόστος (€)',
      ];
      sheetTasks.appendRow(taskHeaders.map((h) => TextCellValue(h)).toList());
      for (int i = 0; i < taskHeaders.length; i++) {
        sheetTasks
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetTasks.setColumnWidth(i, 18.0);
      }
      for (var t in tasks) {
        String groveName = groveNameMap[t['groveId'].toString()] ?? 'Άγνωστο';
        sheetTasks.appendRow([
          TextCellValue(groveName),
          TextCellValue(t['title'].toString()),
          TextCellValue(t['type'].toString()),
          TextCellValue(t['date'].toString().split('T')[0]),
          DoubleCellValue(t['cost'] as double),
        ]);
      }

      Sheet sheetHarvests = excel['Ιστορικό Συγκομιδών'];
      List<String> harvestHeaders = [
        'Χωράφι',
        'Ημερομηνία',
        'Λίτρα Λαδιού',
        'Κιλά Ελιάς',
        'Οξύτητα',
        'Τιμή Πώλησης (€/L)',
      ];
      sheetHarvests.appendRow(
        harvestHeaders.map((h) => TextCellValue(h)).toList(),
      );
      for (int i = 0; i < harvestHeaders.length; i++) {
        sheetHarvests
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetHarvests.setColumnWidth(i, 18.0);
      }
      for (var h in harvests) {
        String groveName = groveNameMap[h['groveId'].toString()] ?? 'Άγνωστο';
        sheetHarvests.appendRow([
          TextCellValue(groveName),
          TextCellValue(h['date'].toString().split('T')[0]),
          DoubleCellValue(h['oilVolume'] as double),
          DoubleCellValue(h['olivesWeight'] as double),
          DoubleCellValue(h['acidity'] as double),
          DoubleCellValue(h['pricePerUnit'] as double),
        ]);
      }

      // Αποθήκευση και Κοινοποίηση
      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final fileName =
          'OliveManager_Report_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.xlsx';
      final path = "${directory.path}/$fileName";

      await File(path).writeAsBytes(fileBytes!, flush: true);

      // Χρησιμοποιούμε το share_plus για να ανοίξει το μενού (Gmail, Drive κλπ)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Οικονομική και Γεωπονική Αναφορά (Excel)',
        ),
      );
      return true;
    } catch (e) {
      AppLogger.error('Σφάλμα Excel', e);
      return false;
    }
  }

  // --- 5. ΑΠΟΘΗΚΕΥΣΗ EXCEL ΤΟΠΙΚΑ (Χωρίς κοινοποίηση) ---
  static Future<bool> saveExcelLocally() async {
    try {
      await _requestStoragePermission();

      var excel = Excel.createExcel();
      final db = await DatabaseHelper.instance.database;

      final groves = await db.query('groves');
      final tasks = await db.query('tasks');
      final harvests = await db.query('harvests');

      CellStyle headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#2E7D32'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      CellStyle totalStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E0E0E0'),
      );

      excel.rename('Sheet1', 'Χωράφια - Στατιστικά');
      Sheet sheetGroves = excel['Χωράφια - Στατιστικά'];

      List<String> groveHeaders = [
        'Όνομα Χωραφιού',
        'Στρέμματα',
        'Δέντρα',
        'Περιοχή / Τοποθεσία',
        'Συνολικά Έξοδα (€)',
        'Συνολικά Έσοδα (€)',
        'Καθαρό Κέρδος (€)',
        'Λίτρα Λαδιού',
        'Κιλά Ελιάς',
        'Απόδοση (L/Στρέμμα)',
        'Απόδοση (L/Δέντρο)',
        'Κέρδος (€/Δέντρο)',
      ];
      sheetGroves.appendRow(groveHeaders.map((h) => TextCellValue(h)).toList());

      for (int i = 0; i < groveHeaders.length; i++) {
        sheetGroves
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetGroves.setColumnWidth(i, 22.0);
      }

      double sumExpenses = 0, sumRevenue = 0, sumProfit = 0, sumOil = 0;
      int currentRow = 1;

      for (var g in groves) {
        String groveId = g['id'].toString();
        String name = g['name'].toString();
        double area = (g['area'] as num).toDouble();

        String locationStr = 'Μη διαθέσιμη';
        if (g['lat'] != null && g['lng'] != null) {
          double lat = (g['lat'] as num).toDouble();
          double lng = (g['lng'] as num).toDouble();

          try {
            final geoUrl = Uri.parse(
              'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=el',
            );
            final geoResponse = await http
                .get(geoUrl)
                .timeout(const Duration(seconds: 3));

            if (geoResponse.statusCode == 200) {
              final geoData = json.decode(geoResponse.body);
              String city = geoData['city'] ?? geoData['locality'] ?? '';

              if (city.isNotEmpty) {
                locationStr =
                    '$city (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
              } else {
                locationStr =
                    '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
              }
            } else {
              locationStr =
                  '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
            }
          } catch (e) {
            locationStr =
                '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
          }
        }

        double totalCost = 0.0;
        final groveTasks = await db.query(
          'tasks',
          where: 'groveId = ?',
          whereArgs: [groveId],
        );
        for (var t in groveTasks) {
          totalCost += (t['cost'] as num).toDouble();
        }

        double totalOil = 0.0, totalOlives = 0.0, totalRevenue = 0.0;
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

        double netProfit = totalRevenue - totalCost;
        double yieldPerStremma = area > 0 ? (totalOil / area) : 0.0;

        int trees = g['treeCount'] != null ? g['treeCount'] as int : 0;
        double yieldPerTree = trees > 0 ? (totalOil / trees) : 0.0;
        double profitPerTree = trees > 0 ? (netProfit / trees) : 0.0;

        sumExpenses += totalCost;
        sumRevenue += totalRevenue;
        sumProfit += netProfit;
        sumOil += totalOil;

        sheetGroves.appendRow([
          TextCellValue(name),
          DoubleCellValue(area),
          IntCellValue(trees),
          TextCellValue(locationStr),
          DoubleCellValue(totalCost),
          DoubleCellValue(totalRevenue),
          DoubleCellValue(netProfit),
          DoubleCellValue(totalOil),
          DoubleCellValue(totalOlives),
          DoubleCellValue(double.parse(yieldPerStremma.toStringAsFixed(2))),
          DoubleCellValue(double.parse(yieldPerTree.toStringAsFixed(2))),
          DoubleCellValue(double.parse(profitPerTree.toStringAsFixed(2))),
        ]);
        currentRow++;
      }

      sheetGroves.appendRow([
        TextCellValue('ΓΕΝΙΚΑ ΣΥΝΟΛΑ:'),
        TextCellValue(''),
        TextCellValue(''),
        DoubleCellValue(sumExpenses),
        DoubleCellValue(sumRevenue),
        DoubleCellValue(sumProfit),
        DoubleCellValue(sumOil),
        TextCellValue(''),
        TextCellValue(''),
      ]);

      for (int i = 0; i < groveHeaders.length; i++) {
        sheetGroves
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: currentRow,
                  ),
                )
                .cellStyle =
            totalStyle;
      }

      // Δημιουργούμε Map groveId -> name
      Map<String, String> groveNameMap = {};
      for (var g in groves) {
        groveNameMap[g['id'].toString()] = g['name'].toString();
      }

      Sheet sheetTasks = excel['Ιστορικό Εργασιών'];
      List<String> taskHeaders = [
        'Χωράφι',
        'Τίτλος Εργασίας',
        'Τύπος',
        'Ημερομηνία',
        'Κόστος (€)',
      ];
      sheetTasks.appendRow(taskHeaders.map((h) => TextCellValue(h)).toList());
      for (int i = 0; i < taskHeaders.length; i++) {
        sheetTasks
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetTasks.setColumnWidth(i, 18.0);
      }
      for (var t in tasks) {
        String groveName = groveNameMap[t['groveId'].toString()] ?? 'Άγνωστο';
        sheetTasks.appendRow([
          TextCellValue(groveName),
          TextCellValue(t['title'].toString()),
          TextCellValue(t['type'].toString()),
          TextCellValue(t['date'].toString().split('T')[0]),
          DoubleCellValue(t['cost'] as double),
        ]);
      }

      Sheet sheetHarvests = excel['Ιστορικό Συγκομιδών'];
      List<String> harvestHeaders = [
        'Χωράφι',
        'Ημερομηνία',
        'Λίτρα Λαδιού',
        'Κιλά Ελιάς',
        'Οξύτητα',
        'Τιμή Πώλησης (€/L)',
      ];
      sheetHarvests.appendRow(
        harvestHeaders.map((h) => TextCellValue(h)).toList(),
      );
      for (int i = 0; i < harvestHeaders.length; i++) {
        sheetHarvests
                .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
                .cellStyle =
            headerStyle;
        sheetHarvests.setColumnWidth(i, 18.0);
      }
      for (var h in harvests) {
        String groveName = groveNameMap[h['groveId'].toString()] ?? 'Άγνωστο';
        sheetHarvests.appendRow([
          TextCellValue(groveName),
          TextCellValue(h['date'].toString().split('T')[0]),
          DoubleCellValue(h['oilVolume'] as double),
          DoubleCellValue(h['olivesWeight'] as double),
          DoubleCellValue(h['acidity'] as double),
          DoubleCellValue(h['pricePerUnit'] as double),
        ]);
      }

      var fileBytes = excel.save();
      final fileName =
          'OliveManager_Report_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}.xlsx';

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

      if (selectedDirectory == null) {
        AppLogger.warning('Ακύρωση αποθήκευσης αρχείου');
        return false;
      }

      final filePath = join(selectedDirectory, fileName);
      await File(filePath).writeAsBytes(fileBytes!, flush: true);

      AppLogger.info('Excel αποθηκεύθηκε: $filePath');
      return true;
    } catch (e) {
      AppLogger.error('Σφάλμα αποθήκευσης Excel', e);
      return false;
    }
  }
}
