import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/database_helper.dart';
import 'dart:developer' as developer;

class PdfService {
  // 1. ΙΔΙΩΤΙΚΗ ΣΥΝΑΡΤΗΣΗ: Χτίζει το έγγραφο (Κεντρική Λογική)
  static Future<pw.Document> _buildPdfDocument() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final db = await DatabaseHelper.instance.database;
    final groves = await db.query('groves');

    double globalExpenses = 0.0;
    double globalRevenue = 0.0;
    double globalOil = 0.0;
    List<List<String>> tableData = [];

    for (var g in groves) {
      String groveId = g['id'].toString();
      String name = g['name'].toString();
      double area = (g['area'] as num).toDouble();

      double cost = 0.0;
      final tasks = await db.query(
        'tasks',
        where: 'groveId = ?',
        whereArgs: [groveId],
      );
      for (var t in tasks) {
        cost += (t['cost'] as num).toDouble();
      }

      double oil = 0.0;
      double revenue = 0.0;
      final harvests = await db.query(
        'harvests',
        where: 'groveId = ?',
        whereArgs: [groveId],
      );
      for (var h in harvests) {
        double currentOil = (h['oilVolume'] as num).toDouble();
        oil += currentOil;
        revenue += currentOil * (h['pricePerUnit'] as num).toDouble();
      }

      double profit = revenue - cost;
      // double yieldPerStremma = area > 0 ? (oil / area) : 0.0;
      int trees = g['treeCount'] != null ? g['treeCount'] as int : 0;
      double oilPerTree = trees > 0 ? (oil / trees) : 0.0;

      globalExpenses += cost;
      globalRevenue += revenue;
      globalOil += oil;

      tableData.add([
        name,
        '${area.toStringAsFixed(1)} Στρ.',
        '$trees', // ΝΕΟ: Εμφάνιση Αριθμού Δέντρων
        '${cost.toStringAsFixed(2)} €',
        '${revenue.toStringAsFixed(2)} €',
        '${profit.toStringAsFixed(2)} €',
        '${oilPerTree.toStringAsFixed(1)} L', // ΝΕΟ: Αλλάξαμε την απόδοση σε Λίτρα ανά Δέντρο!
      ]);
    }

    double globalProfit = globalRevenue - globalExpenses;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OLIVE MANAGER',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800,
                      ),
                    ),
                    pw.Text(
                      'Σύστημα Διαχείρισης Ελαιοκομίας',
                      style: const pw.TextStyle(
                        fontSize: 12,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'ΑΝΑΦΟΡΑ ΑΠΟΔΟΣΗΣ',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Ημερομηνία: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Συνολικά Έξοδα',
                    '${globalExpenses.toStringAsFixed(2)} €',
                    PdfColors.red700,
                  ),
                  _buildSummaryItem(
                    'Συνολικά Έσοδα',
                    '${globalRevenue.toStringAsFixed(2)} €',
                    PdfColors.green700,
                  ),
                  _buildSummaryItem(
                    'Καθαρό Κέρδος',
                    '${globalProfit.toStringAsFixed(2)} €',
                    globalProfit >= 0 ? PdfColors.blue700 : PdfColors.orange700,
                  ),
                  _buildSummaryItem(
                    'Σύνολο Λαδιού',
                    '${globalOil.toStringAsFixed(1)} L',
                    PdfColors.black,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Αναλυτικά Στοιχεία ανά Χωράφι',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: [
                'Χωράφι',
                'Στρέμματα',
                'Δέντρα',
                'Έξοδα',
                'Έσοδα',
                'Κέρδος',
                'L/Δέντρο',
              ], // Ανανεωμένα Headers
              data: tableData,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green700,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.center,
                2: pw.Alignment.center, // Στοίχιση για τα δέντρα
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
                6: pw.Alignment.center, // Στοίχιση για το L/Δέντρο
              },
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey50),
            ),
          ];
        },
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'Σελίδα ${context.pageNumber} από ${context.pagesCount}',
            style: const pw.TextStyle(color: PdfColors.grey),
          ),
        ),
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryItem(
    String title,
    String value,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ΛΕΙΤΟΥΡΓΙΑ Α: ΕΚΤΥΠΩΣΗ / ΠΡΟΕΠΙΣΚΟΠΗΣΗ
  // ==========================================
  static Future<void> printReport() async {
    try {
      final pdf = await _buildPdfDocument();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'OliveManager_Report_${DateTime.now().day}_${DateTime.now().month}.pdf',
      );
    } catch (e) {
      developer.log('[ERROR] PDF Print Error: $e', level: 900);
      rethrow; // Θα δειχθεί error στο UI
    }
  }

  // ==========================================
  // ΛΕΙΤΟΥΡΓΙΑ Β: ΝΕΟ! ΚΟΙΝΟΠΟΙΗΣΗ (GMAIL, DRIVE)
  // ==========================================
  static Future<void> shareReport() async {
    try {
      final pdf = await _buildPdfDocument();
      final bytes = await pdf.save(); // Μετατροπή σε ψηφιακά δεδομένα

      // Ανοίγει το σύστημα του Android/iOS για Gmail, Drive, Viber κλπ
      await Printing.sharePdf(
        bytes: bytes,
        filename:
            'OliveManager_Report_${DateTime.now().day}_${DateTime.now().month}.pdf',
      );
    } catch (e) {
      developer.log('[ERROR] PDF Share Error: $e', level: 900);
      rethrow; // Θα δειχθεί error στο UI
    }
  }
}
