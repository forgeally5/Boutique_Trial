import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BoutiquePdfGenerator {
  static pw.Font? _fontRegular;
  static pw.Font? _fontBold;
  static pw.Font? _fontSerif;
  static pw.Font? _fontScript;

  static pw.Widget _underlineText(String text, PdfColor goldLine, PdfColor textDark) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: goldLine, width: 0.5)),
      ),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, color: textDark),
      ),
    );
  }

  static Future<Uint8List> generate(Map<String, dynamic> bill) async {
    final fmt = DateFormat('dd/MM/yyyy');
    final pdf = pw.Document();

    _fontRegular ??= await PdfGoogleFonts.montserratRegular();
    _fontBold ??= await PdfGoogleFonts.montserratBold();
    _fontSerif ??= await PdfGoogleFonts.playfairDisplayRegular();
    _fontScript ??= await PdfGoogleFonts.greatVibesRegular();

    final fontRegular = _fontRegular!;
    final fontBold = _fontBold!;
    final fontSerif = _fontSerif!;
    final fontScript = _fontScript!;

    // Colors matching the design
    final bgColor = PdfColor.fromInt(0xFFF9F6F0);
    final maroon = PdfColor.fromInt(0xFF5A121A); // Deep red/maroon
    final goldLine = PdfColor.fromInt(0xFFC7B492); // Goldish color for lines
    final textDark = PdfColor.fromInt(0xFF333333);
    final textLight = PdfColor.fromInt(0xFF666666);

    final billType = bill['billType']?.toString() ?? 'Sale';
    final narration = bill['narration']?.toString().trim() ?? '';
    final paymentMode = bill['paymentMode']?.toString() ?? 'Cash';

    final billNo = bill['billNo']?.toString() ?? '';
    final rawDate = bill['billDate'];
    final billDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final customerName = bill['customerName']?.toString().trim() ?? '';
    final customerMobile = bill['customerMobile']?.toString().trim() ?? '';
    final customerAddress = bill['customerAddress']?.toString().trim() ?? '';
    
    final items = (bill['items'] as List<dynamic>?) ?? [];
    
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discAmt = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0;
    final taxAmt = (bill['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0.0;

    pw.Widget underlineText(String text) => _underlineText(text, goldLine, textDark);

    pw.Widget pdfCell(String text, {bool isHeader = false, pw.Alignment align = pw.Alignment.center}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        alignment: align,
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isHeader ? PdfColors.white : textDark,
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          // 5 inches wide, 12 inches high
          pageFormat: const PdfPageFormat(5 * 72, 12 * 72),
          margin: const pw.EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
          buildBackground: (context) => pw.Container(color: bgColor),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // TOP SECTION
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Area
                    pw.Expanded(
                      flex: 6,
                      child: pw.Center(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Text(
                              'RITUMITA BOUTIQUE',
                              style: pw.TextStyle(
                                font: fontSerif,
                                color: maroon,
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Container(height: 0.5, color: goldLine, width: 100),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 20),
                    // Invoice Area
                    pw.Expanded(
                      flex: 4,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            billType == 'Advance Payment' ? 'ADVANCE' : 'INVOICE',
                            style: pw.TextStyle(
                              font: fontSerif,
                              fontSize: 16,
                              color: maroon,
                              letterSpacing: 1.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(height: 0.5, color: goldLine, width: double.infinity),
                          pw.SizedBox(height: 8),
                          // Details
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('INVOICE NO.', style: pw.TextStyle(fontSize: 6, color: textLight)),
                              underlineText(billNo),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('DATE', style: pw.TextStyle(fontSize: 6, color: textLight)),
                              underlineText(fmt.format(billDate)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                
                // INVOICE TO
                pw.Text('INVOICE TO', style: pw.TextStyle(fontSize: 8, letterSpacing: 1, color: textDark, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                underlineText(customerName.isEmpty ? 'Walk-in Customer' : customerName),
                pw.SizedBox(height: 4),
                underlineText(customerMobile.isEmpty ? ' ' : 'Phone: $customerMobile'),
                pw.SizedBox(height: 4),
                underlineText(customerAddress.isEmpty ? ' ' : customerAddress),
                pw.SizedBox(height: 20),

                // TABLE
                pw.Table(
                  border: pw.TableBorder.all(color: goldLine, width: 0.5),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8),
                    1: const pw.FlexColumnWidth(3),
                    2: const pw.FlexColumnWidth(1.2),
                    3: const pw.FlexColumnWidth(0.8),
                    4: const pw.FlexColumnWidth(1.2),
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: maroon),
                      children: [
                        pdfCell('NO', isHeader: true, align: pw.Alignment.center),
                        pdfCell('PRODUCT DESCRIPTION', isHeader: true, align: pw.Alignment.centerLeft),
                        pdfCell('PRICE', isHeader: true, align: pw.Alignment.center),
                        pdfCell('QTY', isHeader: true, align: pw.Alignment.center),
                        pdfCell('TOTAL', isHeader: true, align: pw.Alignment.center),
                      ],
                    ),
                    // Data Rows
                    ...items.asMap().entries.map((e) {
                      final i = e.key + 1;
                      final r = e.value as Map<String, dynamic>;
                      final itemName = r['name']?.toString() ?? '';
                      final qty = (r['qty'] as num?)?.toDouble() ?? 1.0;
                      final price = (r['price'] as num?)?.toDouble() ?? 0.0;
                      final lineAmt = (r['lineAmount'] as num?)?.toDouble() ?? 0.0;
                      
                      return pw.TableRow(
                        children: [
                          pdfCell(i.toString(), align: pw.Alignment.center),
                          pdfCell(itemName, align: pw.Alignment.centerLeft),
                          pdfCell(price.toStringAsFixed(2), align: pw.Alignment.center),
                          pdfCell(qty.toInt().toString(), align: pw.Alignment.center),
                          pdfCell(lineAmt.toStringAsFixed(2), align: pw.Alignment.center),
                        ],
                      );
                    }),
                    // Fill remaining rows if too few items (optional, to keep layout)
                    if (items.length < 5)
                      ...List.generate(5 - items.length, (index) {
                        return pw.TableRow(
                          children: [
                            pdfCell(' '),
                            pdfCell(' '),
                            pdfCell(' '),
                            pdfCell(' '),
                            pdfCell(' '),
                          ],
                        );
                      }),
                  ],
                ),
                pw.SizedBox(height: 20),

                // BOTTOM SECTION
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Payment Details
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('PAYMENT DETAILS', style: pw.TextStyle(fontSize: 8, letterSpacing: 1, color: textDark, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 8),
                          pw.Row(
                            children: [
                              pw.Text('MODE   ', style: pw.TextStyle(fontSize: 7, color: textLight)),
                              pw.Expanded(child: underlineText(paymentMode)),
                            ]
                          ),
                          pw.SizedBox(height: 6),
                          pw.Row(
                            children: [
                              pw.Text('REMARKS ', style: pw.TextStyle(fontSize: 7, color: textLight)),
                              pw.Expanded(child: underlineText(narration)),
                            ]
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    // Totals
                    pw.Expanded(
                      flex: 5,
                      child: pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border(left: pw.BorderSide(color: goldLine, width: 1)),
                        ),
                        padding: const pw.EdgeInsets.only(left: 10),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('SUBTOTAL', style: pw.TextStyle(fontSize: 7, color: textLight, letterSpacing: 1)),
                                underlineText(subtotal.toStringAsFixed(2)),
                              ],
                            ),
                            if (taxAmt > 0) ...[
                              pw.SizedBox(height: 6),
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                children: [
                                  pw.Text('TAX', style: pw.TextStyle(fontSize: 7, color: textLight, letterSpacing: 1)),
                                  underlineText(taxAmt.toStringAsFixed(2)),
                                ],
                              ),
                            ],
                            pw.SizedBox(height: 6),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('DISCOUNT', style: pw.TextStyle(fontSize: 7, color: textLight, letterSpacing: 1)),
                                underlineText(discAmt.toStringAsFixed(2)),
                              ],
                            ),
                            pw.SizedBox(height: 10),
                            pw.Container(height: 0.5, color: goldLine, width: double.infinity),
                            pw.SizedBox(height: 6),
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                              children: [
                                pw.Text('TOTAL', style: pw.TextStyle(fontSize: 10, color: maroon, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
                                underlineText(total.toStringAsFixed(2)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 40),

                // Thank you section
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Thank You',
                          style: pw.TextStyle(font: fontScript, fontSize: 32, color: maroon),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'FOR YOUR TRUST & SUPPORT',
                          style: pw.TextStyle(fontSize: 6, color: textLight, letterSpacing: 1),
                        ),
                      ],
                    ),
                    // Address block as requested
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('RituMita', style: pw.TextStyle(fontSize: 8, color: maroon, fontWeight: pw.FontWeight.bold)),
                        pw.Text('+91 98765 43210', style: pw.TextStyle(fontSize: 7, color: textLight)),
                        pw.Text('www.ritumita.com', style: pw.TextStyle(fontSize: 7, color: textLight)),
                        pw.Text('123 Fashion St., Chennai', style: pw.TextStyle(fontSize: 7, color: textLight)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
