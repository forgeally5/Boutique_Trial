// pdf_invoice_api.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:printing/printing.dart';

class SalesInvoiceData {
  final String customerName;
  final String customerMobile;
  final String customerAddress;
  final String customerState;
  final String invoiceNo;
  final String date;
  final String placeOfSupply;
  
  final List<InvoiceItem> items;
  
  final double totalPcs;
  final double totalGrossWt;
  final double totalNetWt;
  final double totalMetalAmt;
  final double totalAmount;
  
  final double discountAmt;
  final double taxableAmount;
  final double cgstAmt;
  final double sgstAmt;
  final double igstAmt;
  final double roundOff;
  final double grossAmount;
  final double receivedAmt;
  
  final String amountInWords;
  final String cardDetails;

  // New fields
  final String customerPan;
  final String narration;
  final double dueAmount;
  final String receiptDetails;
  final String credits;

  SalesInvoiceData({
    required this.customerName,
    required this.customerMobile,
    required this.customerAddress,
    required this.customerState,
    required this.invoiceNo,
    required this.date,
    required this.placeOfSupply,
    required this.items,
    required this.totalPcs,
    required this.totalGrossWt,
    required this.totalNetWt,
    required this.totalMetalAmt,
    required this.totalAmount,
    required this.discountAmt,
    required this.taxableAmount,
    required this.cgstAmt,
    required this.sgstAmt,
    required this.igstAmt,
    required this.roundOff,
    required this.grossAmount,
    required this.receivedAmt,
    required this.amountInWords,
    required this.cardDetails,
    this.customerPan = '',
    this.narration = '',
    this.dueAmount = 0.0,
    this.receiptDetails = '',
    this.credits = '',
  });
}

class InvoiceItem {
  final String description;
  final int pcs;
  final String purity;
  final double grossWt;
  final double netWt;
  final double rate;
  final double metalAmount;
  final double diaAmount;
  final double labour;
  final double colStAndOtChg;
  final double amount;

  // New fields
  final double labourAmount;
  final String labourRateStr;

  InvoiceItem({
    required this.description,
    required this.pcs,
    required this.purity,
    required this.grossWt,
    required this.netWt,
    required this.rate,
    required this.metalAmount,
    required this.diaAmount,
    required this.labour,
    required this.colStAndOtChg,
    required this.amount,
    this.labourAmount = 0.0,
    this.labourRateStr = '',
  });
}

class PdfInvoiceApi {
  static String numberToWords(double amount) {
    final int value = amount.floor();
    if (value == 0) return 'Zero Only';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten',
      'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];

    String convertLessThanThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return '${units[n]} ';
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]} ';
      return '${units[n ~/ 100]} Hundred ${convertLessThanThousand(n % 100)}';
    }

    String result = '';
    int temp = value;

    if (temp >= 10000000) {
      result += '${convertLessThanThousand(temp ~/ 10000000)}Crore ';
      temp %= 10000000;
    }
    if (temp >= 100000) {
      result += '${convertLessThanThousand(temp ~/ 100000)}Lakh ';
      temp %= 100000;
    }
    if (temp >= 1000) {
      result += '${convertLessThanThousand(temp ~/ 1000)}Thousand ';
      temp %= 1000;
    }
    if (temp > 0) {
      result += convertLessThanThousand(temp);
    }

    return '${result.trim()} Only';
  }

  static Future<Uint8List> generate(SalesInvoiceData data) async {
    // 1. Fetch template settings dynamically from Firestore
    String businessName = 'FORGEALLY';
    String subtitle = 'BOUTIQUE RETAIL';
    String address = 'Your Shop Address, City - 000000. Tamil Nadu, INDIA';
    String gstNo = '';
    String footerText = 'Thank you for shopping with us!';
    bool showLogo = true;
    bool includeSignatureBlock = true;
    String themeColor = 'Brown';

    try {
      final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        final d = doc.data()!;
        businessName = d['businessName']?.toString() ?? businessName;
        subtitle = d['subtitle']?.toString() ?? subtitle;
        address = d['address']?.toString() ?? address;
        gstNo = d['gstNo']?.toString() ?? gstNo;
        footerText = d['footerText']?.toString() ?? footerText;
        showLogo = d['showLogo'] ?? showLogo;
        includeSignatureBlock = d['includeSignatureBlock'] ?? includeSignatureBlock;
        themeColor = d['themeColor']?.toString() ?? themeColor;
      }
    } catch (e) {
      // Fallback to hardcoded defaults
    }

    // 2. Try loading the assets image for the logo
    pw.MemoryImage? logoImage;
    if (showLogo) {
      try {
        final byteData = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(byteData.buffer.asUint8List());
      } catch (e) {
        // Fallback to monogram box if assets fail to load
      }
    }

    final Map<String, PdfColor> themes = {
      'Brown': const PdfColor.fromInt(0xFF3E2723),
      'Navy': const PdfColor.fromInt(0xFF1A237E),
      'Emerald': const PdfColor.fromInt(0xFF1B5E20),
      'Slate': const PdfColor.fromInt(0xFF263238),
    };
    final Map<String, PdfColor> lightThemes = {
      'Brown': const PdfColor.fromInt(0xFFF7F5F2), // Solid very light brown tint
      'Navy': const PdfColor.fromInt(0xFFECEFFB),  // Solid very light navy tint
      'Emerald': const PdfColor.fromInt(0xFFEDF7ED), // Solid very light green tint
      'Slate': const PdfColor.fromInt(0xFFECEFF1),   // Solid very light grey tint
    };
    final tColor = themes[themeColor] ?? const PdfColor.fromInt(0xFF3E2723);
    final tLightColor = lightThemes[themeColor] ?? const PdfColor.fromInt(0xFFF7F5F2);

    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: fontRegular,
        bold: fontBold,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(businessName, subtitle, address, gstNo, showLogo, logoImage, tColor),
        footer: (context) => _buildFooter(footerText),
        build: (context) => [
          _buildInvoiceInfo(data, tColor, tLightColor),
          pw.SizedBox(height: 8),
          _buildTable(data, tColor),
          _buildTotals(data, footerText, includeSignatureBlock, tColor, businessName, subtitle, tLightColor),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(String businessName, String subtitle, String address, String gstNo, bool showLogo, pw.MemoryImage? logoImage, PdfColor tColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('', style: const pw.TextStyle(fontSize: 8)),
            pw.Text('GSTIN No.: ${gstNo.toUpperCase()}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: tColor)),
          ]
        ),
        pw.SizedBox(height: 4),
        if (showLogo && logoImage != null)
          pw.Container(
            height: 44,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          )
        else if (showLogo)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: tColor, width: 2),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Text(
              businessName.isNotEmpty ? businessName[0].toUpperCase() : 'T',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: tColor),
            ),
          ),
        pw.SizedBox(height: 6),
        pw.Text(businessName.toUpperCase(), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, letterSpacing: 2, color: tColor)),
        if (subtitle.isNotEmpty)
          pw.Text(subtitle.toUpperCase(), style: pw.TextStyle(fontSize: 10, letterSpacing: 3, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(address, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
        pw.SizedBox(height: 8),
        pw.Container(height: 1.5, color: tColor),
        pw.SizedBox(height: 10),
      ]
    );
  }

  static pw.Widget _buildInvoiceInfo(SalesInvoiceData data, PdfColor tColor, PdfColor tLightColor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: tColor, width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Name', data.customerName),
                _buildInfoRow('Address', data.customerAddress),
                pw.SizedBox(height: 16),
                _buildInfoRow('Mobile', data.customerMobile),
                pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 6,
                      child: _buildInfoRow('State', PdfInvoiceApi.getStateWithCode(data.customerState)),
                    ),
                    if (data.customerPan.trim().isNotEmpty)
                      pw.Expanded(
                        flex: 4,
                        child: _buildInfoRow('PAN No', data.customerPan.trim(), titleWidth: 40),
                      )
                    else
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(),
                      ),
                  ],
                ),
              ]
            )
          )
        ),
        pw.Expanded(
          flex: 4,
          child: pw.Column(
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: tColor, width: 1),
                  color: tLightColor,
                ),
                child: pw.Center(child: pw.Text('TAX INVOICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: tColor))),
              ),
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tColor, width: 1),
                    right: pw.BorderSide(color: tColor, width: 1),
                    bottom: pw.BorderSide(color: tColor, width: 1),
                  ),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('DEBIT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tColor))))),
                    pw.Container(width: 1, height: 16, color: tColor),
                    pw.Expanded(child: pw.Center(child: pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Text('ORIGINAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tColor))))),
                  ]
                )
              ),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tColor, width: 1),
                    right: pw.BorderSide(color: tColor, width: 1),
                    bottom: pw.BorderSide(color: tColor, width: 1),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Invoice No.', data.invoiceNo),
                    _buildInfoRow('Date', data.date),
                    _buildInfoRow('Place Of Supply', PdfInvoiceApi.getStateWithCode(data.placeOfSupply)),
                  ]
                )
              )
            ]
          )
        )
      ]
    );
  }

  static pw.Widget _buildInfoRow(String title, String value, {double titleWidth = 70}) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: titleWidth, child: pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9))),
        pw.Text(': ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Expanded(child: pw.Text(value, style: const pw.TextStyle(fontSize: 9))),
      ]
    );
  }

  static pw.Widget _buildTable(SalesInvoiceData data, PdfColor tColor) {
    final headers = [
      'Sr.',
      'Description',
      'Pcs',
      'Purity',
      'Gross\nWt.',
      'Net Wt.',
      'Rate',
      'Metal\nAmount',
      'Dia.\nAmount',
      'Labour',
      'Col.St.&\nOt.Chg.',
      'Amount'
    ];

    final dataRows = data.items.asMap().entries.map((entry) {
      final index = entry.key + 1;
      final item = entry.value;
      final labourText = (item.labourRateStr.isNotEmpty || item.labourAmount > 0)
          ? '${item.labourRateStr.isNotEmpty ? item.labourRateStr : item.labour.toStringAsFixed(2)}\n[${item.labourAmount > 0 ? item.labourAmount.toStringAsFixed(2) : item.labour.toStringAsFixed(2)}]'
          : '';
      return [
        index.toString(),
        item.description,
        item.pcs.toString(),
        item.purity,
        item.grossWt.toStringAsFixed(3),
        item.netWt.toStringAsFixed(3),
        item.rate.toStringAsFixed(2),
        item.metalAmount.toStringAsFixed(2),
        item.diaAmount > 0 ? item.diaAmount.toStringAsFixed(2) : '',
        labourText,
        item.colStAndOtChg > 0 ? item.colStAndOtChg.toStringAsFixed(2) : '',
        item.amount.toStringAsFixed(2),
      ];
    }).toList();

    // Pad with empty rows to fill the height down to the bottom totals block
    const int minRows = 12;
    if (dataRows.length < minRows) {
      final int padCount = minRows - dataRows.length;
      for (int i = 0; i < padCount; i++) {
        dataRows.add([
          '', // Sr.
          '', // Description
          '', // Pcs
          '', // Purity
          '', // Gross Wt.
          '', // Net Wt.
          '', // Rate
          '', // Metal Amount
          '', // Dia. Amount
          '', // Labour
          '', // Col.St.& Ot.Chg.
          '', // Amount
        ]);
      }
    }

    final cellAlignments = {
      0: pw.Alignment.center,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.center,
      3: pw.Alignment.center,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
      7: pw.Alignment.centerRight,
      8: pw.Alignment.centerRight,
      9: pw.Alignment.centerRight,
      10: pw.Alignment.centerRight,
      11: pw.Alignment.centerRight,
    };

    final columnWidths = {
      0: const pw.FlexColumnWidth(0.5),
      1: const pw.FlexColumnWidth(3.0),
      2: const pw.FlexColumnWidth(0.7),
      3: const pw.FlexColumnWidth(1.0),
      4: const pw.FlexColumnWidth(1.2),
      5: const pw.FlexColumnWidth(1.2),
      6: const pw.FlexColumnWidth(1.2),
      7: const pw.FlexColumnWidth(1.5),
      8: const pw.FlexColumnWidth(1.2),
      9: const pw.FlexColumnWidth(1.2),
      10: const pw.FlexColumnWidth(1.2),
      11: const pw.FlexColumnWidth(1.5),
    };

    final List<pw.TableRow> tableRows = [];

    // 1. Header row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: tColor),
        children: headers.asMap().entries.map((e) {
          final i = e.key;
          final h = e.value;
          return pw.Container(
            height: 20,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            alignment: cellAlignments[i] ?? pw.Alignment.center,
            child: pw.Align(
              alignment: cellAlignments[i] ?? pw.Alignment.center,
              child: pw.Text(
                h,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              ),
            ),
          );
        }).toList(),
      ),
    );

    // 2. Data rows
    for (int rowIndex = 0; rowIndex < dataRows.length; rowIndex++) {
      final rowData = dataRows[rowIndex];
      final isRealRow = rowIndex < data.items.length;

      tableRows.add(
        pw.TableRow(
          children: rowData.asMap().entries.map((e) {
            final colIndex = e.key;
            final cellText = e.value;
            return pw.Container(
              constraints: const pw.BoxConstraints(minHeight: 18),
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              alignment: cellAlignments[colIndex] ?? pw.Alignment.centerRight,
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  right: colIndex < 11 ? pw.BorderSide(color: tColor, width: 1) : pw.BorderSide.none,
                  bottom: isRealRow ? pw.BorderSide(color: tColor, width: 0.5) : pw.BorderSide.none,
                ),
              ),
              child: pw.Align(
                alignment: cellAlignments[colIndex] ?? pw.Alignment.centerRight,
                child: pw.Text(
                  cellText,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: tColor, width: 1),
      ),
      child: pw.Table(
        children: tableRows,
        columnWidths: columnWidths,
      ),
    );
  }

  static pw.Widget _buildTotals(SalesInvoiceData data, String footerText, bool includeSignatureBlock, PdfColor tColor, String businessName, String subtitle, PdfColor tLightColor) {
    return pw.Column(
      children: [
        // Total row directly under the table
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: tColor, width: 1),
              right: pw.BorderSide(color: tColor, width: 1),
              bottom: pw.BorderSide(color: tColor, width: 1),
            ),
            color: tLightColor,
          ),
          child: pw.Row(
            children: [
              pw.Expanded(flex: 35, child: pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)))),
              pw.Expanded(flex: 7, child: pw.Center(child: pw.Text(data.totalPcs.toInt().toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)))),
              pw.Expanded(flex: 10, child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Expanded(flex: 12, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(data.totalGrossWt.toStringAsFixed(3), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)))),
              pw.Expanded(flex: 12, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(data.totalNetWt.toStringAsFixed(3), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)))),
              pw.Expanded(flex: 12, child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Expanded(flex: 15, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(data.totalMetalAmt.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)))),
              pw.Expanded(flex: 36, child: pw.Text('', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
              pw.Expanded(flex: 15, child: pw.Align(alignment: pw.Alignment.centerRight, child: pw.Padding(padding: const pw.EdgeInsets.only(right: 4), child: pw.Text(data.totalAmount.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor))))),
            ]
          )
        ),
        
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left side (Words, Receipt, Credits)
            pw.Expanded(
              flex: 6,
              child: pw.Column(
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(4),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: tColor, width: 1),
                        bottom: pw.BorderSide(color: tColor, width: 1),
                      ),
                    ),
                    child: pw.Text('Rs. In Words : ${data.amountInWords}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
                  ),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Container(
                          height: 80,
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              left: pw.BorderSide(color: tColor, width: 1),
                              bottom: pw.BorderSide(color: tColor, width: 1),
                              right: pw.BorderSide(color: tColor, width: 1),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Receipt Details', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)),
                              pw.SizedBox(height: 2),
                              pw.Text(data.receiptDetails.isNotEmpty ? data.receiptDetails : '0.00', style: const pw.TextStyle(fontSize: 7)),
                            ]
                          )
                        )
                      ),
                      pw.Expanded(
                        child: pw.Container(
                          height: 80,
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border(
                              bottom: pw.BorderSide(color: tColor, width: 1),
                            ),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('Credits', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)),
                              pw.SizedBox(height: 1),
                              pw.Text(data.credits.isNotEmpty ? data.credits : '—', style: const pw.TextStyle(fontSize: 7)),
                              pw.SizedBox(height: 4),
                              pw.Text('Narration', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: tColor)),
                              pw.SizedBox(height: 1),
                              pw.Text(data.narration.isNotEmpty ? data.narration : '—', style: const pw.TextStyle(fontSize: 7)),
                            ]
                          )
                        )
                      ),
                    ]
                  )
                ]
              )
            ),
            
            // Right side (Totals summary)
            pw.Expanded(
              flex: 4,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    left: pw.BorderSide(color: tColor, width: 1),
                    right: pw.BorderSide(color: tColor, width: 1),
                    bottom: pw.BorderSide(color: tColor, width: 1),
                  ),
                ),
                child: pw.Column(
                  children: [
                    _buildTotalRow('Discount', data.discountAmt, tColor, tLightColor),
                    _buildTotalRow('Taxable Amount', data.taxableAmount, tColor, tLightColor),
                    _buildTotalRow('CGST @ 1.5 %', data.cgstAmt, tColor, tLightColor),
                    _buildTotalRow('SGST @ 1.5 %', data.sgstAmt, tColor, tLightColor),
                    if (data.igstAmt > 0) _buildTotalRow('IGST @ 3.0 %', data.igstAmt, tColor, tLightColor),
                    _buildTotalRow('Round Off', data.roundOff, tColor, tLightColor),
                    _buildTotalRow('Gross Amount', data.grossAmount, tColor, tLightColor, isBold: true, isGrey: true),
                    _buildTotalRow('Received', data.receivedAmt, tColor, tLightColor),
                    _buildTotalRow('Due Amount', data.dueAmount, tColor, tLightColor, isBold: true),
                    _buildTotalRow('', 0, tColor, tLightColor, empty: true),
                  ]
                )
              )
            )
          ]
        ),
        pw.SizedBox(height: 8),
        _buildSignatures(footerText, includeSignatureBlock, tColor, businessName, subtitle),
      ]
    );
  }

  static pw.Widget _buildTotalRow(String label, double value, PdfColor tColor, PdfColor tLightColor, {bool isBold = false, bool isGrey = false, bool empty = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: pw.BoxDecoration(
        color: isGrey ? tLightColor : null,
        border: pw.Border(bottom: pw.BorderSide(color: tColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null, fontSize: 8)),
          if (!empty)
            pw.Text(value.toStringAsFixed(2), style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null, fontSize: 8)),
        ]
      )
    );
  }

  static pw.Widget _buildSignatures(String footerText, bool includeSignatureBlock, PdfColor tColor, String businessName, String subtitle) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(footerText.isNotEmpty ? footerText : 'Subject To COIMBATORE Jurisdiction Only E. & O.E', style: pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 30),
        if (includeSignatureBlock)
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 150, height: 1, color: tColor),
                  pw.SizedBox(height: 2),
                  pw.Text('Customer\'s Signature', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tColor)),
                ]
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('For, ${businessName.toUpperCase()}${subtitle.isNotEmpty ? ' ${subtitle.toUpperCase()}' : ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tColor)),
                  pw.SizedBox(height: 20),
                  pw.Container(width: 150, height: 1, color: tColor),
                  pw.SizedBox(height: 2),
                  pw.Text('Authorised Signatory', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: tColor)),
                ]
              ),
            ]
          )
      ]
    );
  }

  static pw.Widget _buildFooter(String footerText) {
    return pw.Container();
  }

  static final Map<String, String> stateCodes = {
    'jammu & kashmir': '01',
    'jammu and kashmir': '01',
    'himachal pradesh': '02',
    'punjab': '03',
    'chandigarh': '04',
    'uttarakhand': '05',
    'haryana': '06',
    'delhi': '07',
    'rajasthan': '08',
    'uttar pradesh': '09',
    'bihar': '10',
    'sikkim': '11',
    'arunachal pradesh': '12',
    'nagaland': '13',
    'manipur': '14',
    'mizoram': '15',
    'tripura': '16',
    'meghalaya': '17',
    'assam': '18',
    'west bengal': '19',
    'jharkhand': '20',
    'odisha': '21',
    'orissa': '21',
    'chhattisgarh': '22',
    'madhya pradesh': '23',
    'gujarat': '24',
    'daman & diu': '25',
    'daman and diu': '25',
    'dadra & nagar haveli': '26',
    'dadra and nagar haveli': '26',
    'maharashtra': '27',
    'karnataka': '29',
    'goa': '30',
    'lakshadweep': '31',
    'kerala': '32',
    'tamil nadu': '33',
    'tamilnadu': '33',
    'puducherry': '34',
    'pondicherry': '34',
    'andaman & nicobar islands': '35',
    'andaman and nicobar islands': '35',
    'telangana': '36',
    'andhra pradesh': '37',
    'ladakh': '38',
  };

  static String getStateWithCode(String stateName) {
    if (stateName.trim().isEmpty) return '';
    final cleaned = stateName.trim().toLowerCase();
    if (cleaned.contains(RegExp(r'\d{2}'))) {
      return stateName;
    }
    final code = stateCodes[cleaned];
    if (code != null) {
      return '$stateName - $code';
    }
    return stateName;
  }
}
