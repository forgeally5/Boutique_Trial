import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoutiquePdfGenerator {
  static Future<Uint8List> generate(Map<String, dynamic> bill) async {
    final fmt = DateFormat('dd/MM/yyyy');
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    const tColor = PdfColor.fromInt(0xFF5E1729);
    const tLight = PdfColor.fromInt(0xFFF9F6F0);
    const greenColor = PdfColor.fromInt(0xFF2E7D32);

    final billNo = bill['billNo']?.toString() ?? '';
    final rawDate = bill['billDate'];
    final billDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final customerName = bill['customerName']?.toString().trim() ?? '';
    final customerMobile = bill['customerMobile']?.toString().trim() ?? '';
    
    final items = (bill['items'] as List<dynamic>?) ?? [];
    
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discAmt = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0;
    final taxAmt = (bill['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final adjustment = (bill['adjustmentAmount'] as num?)?.toDouble() ?? 0.0;
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0.0;

    pw.Widget pdfCell(String text, {bool bold = false, bool isHeader = false, pw.Alignment align = pw.Alignment.center}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.white : PdfColors.black,
            ),
          ),
        ),
      );
    }

    pw.Widget pdfTotalRow(String label, String value, PdfColor c) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 10, color: c)),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: c)),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('FORGEALLY BOUTIQUE - TAX INVOICE',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: tColor)),
              pw.SizedBox(height: 4),
              pw.Container(height: 1.5, color: tColor),
              pw.SizedBox(height: 10),
            ],
          ),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Bill To', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: tColor)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      customerName.isEmpty ? 'Walk-in Customer' : customerName,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    if (customerMobile.isNotEmpty)
                      pw.Text(customerMobile, style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Invoice No: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.TextSpan(text: billNo, style: const pw.TextStyle(fontSize: 9)),
                  ])),
                  pw.SizedBox(height: 3),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.TextSpan(text: fmt.format(billDate), style: const pw.TextStyle(fontSize: 9)),
                  ])),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: tColor, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(4),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FlexColumnWidth(1.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: tColor),
                children: [
                  pdfCell('#', bold: true, isHeader: true),
                  pdfCell('Item', bold: true, isHeader: true, align: pw.Alignment.centerLeft),
                  pdfCell('Qty', bold: true, isHeader: true),
                  pdfCell('Price (₹)', bold: true, isHeader: true),
                  pdfCell('Discount', bold: true, isHeader: true),
                  pdfCell('Amount (₹)', bold: true, isHeader: true),
                ],
              ),
              ...items.asMap().entries.map((e) {
                final i = e.key + 1;
                final r = e.value as Map<String, dynamic>;
                
                final discountValue = (r['discountValue'] as num?)?.toDouble() ?? 0.0;
                final discountType = r['discountType']?.toString() ?? '₹';
                final discStr = discountValue > 0 ? '${discountValue.toStringAsFixed(2)} $discountType' : '—';
                
                final qty = (r['qty'] as num?)?.toDouble() ?? 1.0;
                final unitLabel = r['unitLabel']?.toString() ?? 'Pcs';
                final qtyStr = '${qty.toInt()} $unitLabel';
                
                final itemName = r['name']?.toString() ?? '';
                final gstRate = (r['gstRate'] as num?)?.toDouble() ?? 0.0;
                final nameText = gstRate > 0 ? '$itemName\n(GST: $gstRate%)' : itemName;
                
                final price = (r['price'] as num?)?.toDouble() ?? 0.0;
                final lineAmount = (r['lineAmount'] as num?)?.toDouble() ?? 0.0;
                
                return pw.TableRow(
                  children: [
                    pdfCell(i.toString()),
                    pdfCell(nameText, align: pw.Alignment.centerLeft),
                    pdfCell(qtyStr),
                    pdfCell('₹${price.toStringAsFixed(2)}'),
                    pdfCell(discStr),
                    pdfCell('₹${lineAmount.toStringAsFixed(2)}'),
                  ],
                );
              }),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                child: pw.Column(
                  children: [
                    pdfTotalRow('Subtotal', '₹${subtotal.toStringAsFixed(2)}', tColor),
                    if (discAmt > 0)
                      pdfTotalRow('Extra Discount', '− ₹${discAmt.toStringAsFixed(2)}', tColor),
                    if (taxAmt > 0)
                      pdfTotalRow('Total GST', '+ ₹${taxAmt.toStringAsFixed(2)}', tColor),
                    if (adjustment != 0)
                      pdfTotalRow('Adjustment', '${adjustment >= 0 ? '+' : ''} ₹${adjustment.toStringAsFixed(2)}', tColor),
                    pw.Container(height: 1, color: tColor),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      color: tLight,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL PAYABLE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: tColor)),
                          pw.Text('₹${total.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: tColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Container(height: 0.5, color: tColor),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Thank you for shopping with ForgeAlly Boutique!', style: pw.TextStyle(fontSize: 9, color: greenColor, fontWeight: pw.FontWeight.bold)),
              pw.Text('This is a computer generated invoice.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
