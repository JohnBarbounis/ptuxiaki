import 'dart:io';
import 'dart:convert'; // ΝΕΟ: Για την αποκωδικοποίηση της τοποθεσίας
import 'package:http/http.dart'
    as http; // ΝΕΟ: Για να καλούμε το API τοποθεσίας
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../services/database_helper.dart';

class BackupService {
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

  // --- 4. ΕΞΑΓΩΓΗ ΣΕ EXCEL ΜΕ ΕΞΥΠΝΗ ΤΟΠΟΘΕΣΙΑ ---
  static Future<bool> exportToExcel() async {
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
        'Περιοχή / Τοποθεσία',
        'Συνολικά Έξοδα (€)',
        'Συνολικά Έσοδα (€)',
        'Καθαρό Κέρδος (€)',
        'Λίτρα Λαδιού',
        'Κιλά Ελιάς',
        'Απόδοση (L/Στρέμμα)',
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

        sumExpenses += totalCost;
        sumRevenue += totalRevenue;
        sumProfit += netProfit;
        sumOil += totalOil;

        sheetGroves.appendRow([
          TextCellValue(name),
          DoubleCellValue(area),
          TextCellValue(locationStr), // Μπαίνει το νέο έξυπνο string!
          DoubleCellValue(totalCost),
          DoubleCellValue(totalRevenue),
          DoubleCellValue(netProfit),
          DoubleCellValue(totalOil),
          DoubleCellValue(totalOlives),
          DoubleCellValue(double.parse(yieldPerStremma.toStringAsFixed(2))),
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
      Sheet sheetTasks = excel['Ιστορικό Εργασιών'];
      List<String> taskHeaders = [
        'ID Χωραφιού',
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
        sheetTasks.appendRow([
          TextCellValue(t['groveId'].toString()),
          TextCellValue(t['title'].toString()),
          TextCellValue(t['type'].toString()),
          TextCellValue(t['date'].toString().split('T')[0]),
          DoubleCellValue(t['cost'] as double),
        ]);
      }

      Sheet sheetHarvests = excel['Ιστορικό Συγκομιδών'];
      List<String> harvestHeaders = [
        'ID Χωραφιού',
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
        sheetHarvests.appendRow([
          TextCellValue(h['groveId'].toString()),
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
