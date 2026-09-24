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

    final fontRegular = await PdfGoogleFonts.montserratRegular();
    final fontBold = await PdfGoogleFonts.montserratBold();
    final fontSerif = await PdfGoogleFonts.playfairDisplayRegular();
    final fontScript = await PdfGoogleFonts.greatVibesRegular();

    final bgColor = PdfColor.fromInt(0xFFF4EFE6);
    final darkBrown = PdfColor.fromInt(0xFF5A3B22);
    final lightBrown = PdfColor.fromInt(0xFF8C6246);

    final billType = bill['billType']?.toString() ?? 'Sale';
    final narration = bill['narration']?.toString().trim() ?? '';
    final amountReceived = (bill['amountReceived'] as num?)?.toDouble() ?? 0.0;
    final pendingBalance = (bill['pendingBalance'] as num?)?.toDouble() ?? 0.0;

    final billNo = bill['billNo']?.toString() ?? '';
    final rawDate = bill['billDate'];
    final billDate = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
    final customerName = bill['customerName']?.toString().trim() ?? '';
    final customerMobile = bill['customerMobile']?.toString().trim() ?? '';
    final customerAddress = bill['customerAddress']?.toString().trim() ?? '';
    final paymentMode = bill['paymentMode']?.toString() ?? 'Cash';
    
    final items = (bill['items'] as List<dynamic>?) ?? [];
    
    final subtotal = (bill['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discAmt = (bill['extraDiscountAmount'] as num?)?.toDouble() ?? 0.0;
    final taxAmt = (bill['taxAmount'] as num?)?.toDouble() ?? 0.0;
    final adjustment = (bill['adjustmentAmount'] as num?)?.toDouble() ?? 0.0;
    final total = (bill['totalPayable'] as num?)?.toDouble() ?? 0.0;

    pw.Widget pdfCell(String text, {bool bold = false, pw.Alignment align = pw.Alignment.center}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: pw.Align(
          alignment: align,
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: darkBrown,
            ),
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          buildBackground: (context) => pw.Container(color: bgColor),
          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        ),
        build: (context) {
          return [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Header
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      // Store Brand Block
                      pw.Container(
                        width: 130,
                        height: 110,
                        color: darkBrown,
                        padding: const pw.EdgeInsets.all(16),
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Icon(const pw.IconData(0xe540), color: PdfColors.white, size: 24), // Localflorist icon
                            pw.SizedBox(height: 12),
                            pw.Text('RituMita',
                              style: pw.TextStyle(
                                font: fontSerif,
                                color: PdfColors.white,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Invoice Title
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.SizedBox(height: 20),
                          pw.Text(
                            billType == 'Advance Payment' ? 'ADVANCE' : 'INVOICE',
                            style: pw.TextStyle(
                              font: fontSerif,
                              fontSize: 36,
                              color: darkBrown,
                              letterSpacing: 3,
                            ),
                          ),
                          pw.SizedBox(height: 8),
                          pw.Container(
                            width: 140,
                            height: 1,
                            color: darkBrown,
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 40),
                  
                  // Invoice To & Details
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('INVOICE TO :', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkBrown, letterSpacing: 1)),
                          pw.SizedBox(height: 6),
                          pw.Text(customerName.isEmpty ? 'Walk-in Customer' : customerName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: lightBrown)),
                          if (customerAddress.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(customerAddress, style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                          ],
                          if (customerMobile.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text('Phone: $customerMobile', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                          ],
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Invoice No. $billNo', style: pw.TextStyle(fontSize: 10, color: lightBrown)),
                          pw.SizedBox(height: 6),
                          pw.Text('Date: ${fmt.format(billDate)}', style: pw.TextStyle(fontSize: 10, color: lightBrown)),
                        ],
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 30),
                  
                  // White Card Content
                  pw.Container(
                    color: PdfColors.white,
                    padding: const pw.EdgeInsets.all(30),
                    child: pw.Column(
                      children: [
                        // Table
                        pw.Table(
                          border: pw.TableBorder(
                            top: pw.BorderSide(color: darkBrown, width: 1),
                            bottom: pw.BorderSide(color: darkBrown, width: 1),
                            horizontalInside: pw.BorderSide.none,
                            verticalInside: pw.BorderSide.none,
                            left: pw.BorderSide.none,
                            right: pw.BorderSide.none,
                          ),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(0.6),
                            1: const pw.FlexColumnWidth(4),
                            2: const pw.FlexColumnWidth(1.5),
                            3: const pw.FlexColumnWidth(1),
                            4: const pw.FlexColumnWidth(1.5),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pdfCell('NO', bold: true, align: pw.Alignment.centerLeft),
                                pdfCell('PRODUCT DESCRIPTION', bold: true, align: pw.Alignment.centerLeft),
                                pdfCell('PRICE', bold: true, align: pw.Alignment.centerRight),
                                pdfCell('QTY', bold: true),
                                pdfCell('TOTAL', bold: true, align: pw.Alignment.centerRight),
                              ],
                            ),
                            // Line separator for header
                            pw.TableRow(
                              children: List.generate(5, (_) => pw.Container(
                                height: 0.5,
                                color: darkBrown,
                              )),
                            ),
                            ...items.asMap().entries.map((e) {
                              final i = e.key + 1;
                              final r = e.value as Map<String, dynamic>;
                              final itemName = r['name']?.toString() ?? '';
                              final qty = (r['qty'] as num?)?.toDouble() ?? 1.0;
                              final price = (r['price'] as num?)?.toDouble() ?? 0.0;
                              final lineAmt = (r['lineAmount'] as num?)?.toDouble() ?? 0.0;
                              
                              return pw.TableRow(
                                children: [
                                  pdfCell(i.toString(), align: pw.Alignment.centerLeft),
                                  pdfCell(itemName, align: pw.Alignment.centerLeft),
                                  pdfCell('Rs ${price.toStringAsFixed(2)}', align: pw.Alignment.centerRight),
                                  pdfCell(qty.toInt().toString()),
                                  pdfCell('Rs ${lineAmt.toStringAsFixed(2)}', align: pw.Alignment.centerRight),
                                ],
                              );
                            }),
                          ],
                        ),
                        pw.SizedBox(height: 40),
                        
                        // Totals & Details Row
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            // Payment Details
                            pw.Expanded(
                              flex: 1,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('Payment Details :', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                  pw.SizedBox(height: 6),
                                  pw.Text('Mode: $paymentMode', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                  if (narration.isNotEmpty) ...[
                                    pw.SizedBox(height: 6),
                                    pw.Text('Remarks: $narration', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                  ]
                                ],
                              ),
                            ),
                            // Totals
                            pw.Expanded(
                              flex: 1,
                              child: pw.Column(
                                children: [
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('Subtotal', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                      pw.Text('Rs ${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                    ],
                                  ),
                                  pw.SizedBox(height: 6),
                                  if (discAmt > 0) ...[
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Discount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                        pw.Text('− Rs ${discAmt.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 6),
                                  ],
                                  if (taxAmt > 0) ...[
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Tax (GST)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                        pw.Text('+ Rs ${taxAmt.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 6),
                                  ],
                                  if (adjustment != 0) ...[
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text('Adjustment', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                        pw.Text('${adjustment > 0 ? '+' : ''} Rs ${adjustment.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 6),
                                  ],
                                  pw.Row(
                                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                    children: [
                                      pw.Text('Total', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                      pw.Text('Rs ${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                    ],
                                  ),
                                  if (billType == 'Advance Payment') ...[
                                    pw.SizedBox(height: 6),
                                    pw.Row(
                                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                      children: [
                                        pw.Text(pendingBalance <= 0 ? 'Total Paid' : 'Advance Paid', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                                        pw.Text('Rs ${amountReceived.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                                      ],
                                    ),
                                    pw.SizedBox(height: 6),
                                    if (pendingBalance > 0) ...[
                                      pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('Pending Balance Due', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                                          pw.Text('Rs ${pendingBalance.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                                        ],
                                      ),
                                    ] else ...[
                                      pw.Row(
                                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text('Balance Due', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                                          pw.Text('Rs 0.00 (Fully Paid)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          ];
        },
        footer: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                // Thank You Signature
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Text(
                    'Thank You',
                    style: pw.TextStyle(
                      font: fontScript,
                      fontSize: 48,
                      color: darkBrown,
                    ),
                  ),
                ),
                // Store Details
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('RituMita', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: darkBrown)),
                    pw.SizedBox(height: 4),
                    pw.Text('+91 98765 43210', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                    pw.SizedBox(height: 4),
                    pw.Text('www.ritumita.com', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                    pw.SizedBox(height: 4),
                    pw.Text('123 Fashion St., Chennai', style: pw.TextStyle(fontSize: 9, color: lightBrown)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
