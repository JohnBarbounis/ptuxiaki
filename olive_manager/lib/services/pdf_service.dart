// Αρχείο: lib/services/pdf_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class PdfService {
  // ΝΕΟ: Η συνάρτηση παίρνει πλέον την τιμή του λαδιού ως παράμετρο!
  static Future<void> generateAndShareReport(double oilPrice) async {
    final pdf = pw.Document();

    final greekFont = await PdfGoogleFonts.robotoRegular();
    final greekFontBold = await PdfGoogleFonts.robotoBold();

    final totalExpenses = await DatabaseHelper.instance.getTotalExpenses();
    final totalOil = await DatabaseHelper.instance.getTotalOilProduction();
    final groves = await DatabaseHelper.instance.getAllGroves();

    // ΝΕΟ: Υπολογισμοί μέσα στο PDF
    final grossIncome = totalOil * oilPrice;
    final netProfit = grossIncome - totalExpenses;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Αναφορά Ελαιοπαραγωγής & Εξόδων',
                  style: pw.TextStyle(font: greekFontBold, fontSize: 24),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Ημερομηνία: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(
                    font: greekFont,
                    fontSize: 14,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.SizedBox(height: 30),

              // ---- ΟΙΚΟΝΟΜΙΚΗ ΣΥΝΟΨΗ ΜΕ ΚΕΡΔΟΣ ----
              pw.Text(
                'Οικονομική Σύνοψη',
                style: pw.TextStyle(
                  font: greekFontBold,
                  fontSize: 18,
                  color: PdfColors.green700,
                ),
              ),
              pw.Divider(),
              pw.Text(
                'Συνολική Παραγωγή: ${totalOil.toStringAsFixed(1)} Λίτρα',
                style: pw.TextStyle(font: greekFont, fontSize: 14),
              ),
              pw.Text(
                'Τιμή Πώλησης Λαδιού: ${oilPrice.toStringAsFixed(2)} ευρώ/Λίτρο',
                style: pw.TextStyle(font: greekFont, fontSize: 14),
              ),
              pw.SizedBox(height: 10),

              pw.Text(
                'Μικτά Έσοδα (Πώληση): ${grossIncome.toStringAsFixed(2)} ευρώ',
                style: pw.TextStyle(
                  font: greekFont,
                  fontSize: 14,
                  color: PdfColors.blue700,
                ),
              ),
              pw.Text(
                'Συνολικά Έξοδα Εργασιών: -${totalExpenses.toStringAsFixed(2)} ευρώ',
                style: pw.TextStyle(
                  font: greekFont,
                  fontSize: 14,
                  color: PdfColors.red700,
                ),
              ),
              pw.Divider(),

              // Το Καθαρό Κέρδος (με αλλαγή χρώματος αν είναι θετικό/αρνητικό)
              pw.Text(
                'Καθαρό Κέρδος: ${netProfit.toStringAsFixed(2)} ευρώ',
                style: pw.TextStyle(
                  font: greekFontBold,
                  fontSize: 16,
                  color: netProfit >= 0 ? PdfColors.green700 : PdfColors.red700,
                ),
              ),
              pw.SizedBox(height: 30),

              // ---- ΛΙΣΤΑ ΧΩΡΑΦΙΩΝ ----
              pw.Text(
                'Τα Χωράφια μου',
                style: pw.TextStyle(
                  font: greekFontBold,
                  fontSize: 18,
                  color: PdfColors.blue700,
                ),
              ),
              pw.Divider(),
              if (groves.isEmpty)
                pw.Text(
                  'Δεν υπάρχουν καταχωρημένα χωράφια.',
                  style: pw.TextStyle(font: greekFont, fontSize: 14),
                )
              else
                pw.ListView.builder(
                  itemCount: groves.length,
                  itemBuilder: (context, index) {
                    final grove = groves[index];
                    return pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8.0),
                      child: pw.Text(
                        '• ${grove.name} (${grove.area} στρέμματα)',
                        style: pw.TextStyle(font: greekFont, fontSize: 14),
                      ),
                    );
                  },
                ),

              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Δημιουργήθηκε από το Olive Manager App',
                  style: pw.TextStyle(
                    font: greekFont,
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final outputDirectory = await getTemporaryDirectory();
    final file = File('${outputDirectory.path}/Olive_Report.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Σας αποστέλλω την οικονομική αναφορά ελαιοπαραγωγής.');
  }
}
