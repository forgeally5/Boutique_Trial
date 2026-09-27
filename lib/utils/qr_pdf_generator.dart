import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/product.dart';

class QrPdfGenerator {
  static Future<void> printProductQr(Product product) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          50 * PdfPageFormat.mm, // width
          50 * PdfPageFormat.mm, // height
        ),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text(
                  'RituMita Boutique',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.BarcodeWidget(
                  data: product.tagId,
                  barcode: pw.Barcode.qrCode(),
                  width: 30 * PdfPageFormat.mm,
                  height: 30 * PdfPageFormat.mm,
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  product.tagId,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  product.name,
                  style: const pw.TextStyle(
                    fontSize: 6,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'RituMita_QR_${product.tagId}',
    );
  }
}
