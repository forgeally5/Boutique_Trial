import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/transactions/p_alteration_entry/alteration_entry_view.dart';

class PdfAlterationEntry {
  static Future<Uint8List> generate(AlterationEntry record) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#3E2723'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TRILOK JEWELLERS',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Premium Gold & Diamond Jewellery',
                          style: const pw.TextStyle(
                            color: PdfColors.amber100,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber800,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        record.transactionType.toUpperCase(),
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Transaction Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColor.fromHex('#FCFAF5'),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Voucher No:', record.voucherNo),
                          _buildInfoRow('Voucher Date:', dateFormat.format(record.voucherDate)),
                          _buildInfoRow('Customer Name:', record.customerName),
                          _buildInfoRow('Salesman:', record.salesman.isEmpty ? '-' : record.salesman),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Expected Delivery:', record.expectedDelivery == null ? '-' : dateFormat.format(record.expectedDelivery!)),
                          _buildInfoRow('Repair Type:', record.repairType),
                          _buildInfoRow('Status:', record.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Item Details Section
              pw.Text(
                'ITEM & WEIGHT BREAKDOWN',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E2723'),
                ),
              ),
              pw.SizedBox(height: 8),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(3),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F0E8')),
                    children: [
                      _buildHeaderCell('Tag ID / SKU'),
                      _buildHeaderCell('Item Name'),
                      _buildHeaderCell('Gross Wt (g)'),
                      _buildHeaderCell('Stone Wt (g)'),
                      _buildHeaderCell('Net Wt (g)'),
                      _buildHeaderCell('Purity'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCell(record.tagId.isEmpty ? '-' : record.tagId),
                      _buildCell(record.itemName),
                      _buildCell(record.grossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.stoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.netWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(record.purity.toStringAsFixed(1), align: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              if (record.problemDescription.isNotEmpty) ...[
                pw.Text(
                  'PROBLEM DESCRIPTION:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#3E2723')),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColor.fromHex('#FCFAF5'),
                  ),
                  child: pw.Text(
                    record.problemDescription,
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ),
                pw.SizedBox(height: 14),
              ],

              if (record.remarks.isNotEmpty) ...[
                pw.Text(
                  'REMARKS / NARRATION:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColor.fromHex('#3E2723')),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: pw.BorderRadius.circular(4),
                    color: PdfColor.fromHex('#FCFAF5'),
                  ),
                  child: pw.Text(
                    record.remarks,
                    style: const pw.TextStyle(fontSize: 9.5),
                  ),
                ),
                pw.SizedBox(height: 14),
              ],

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank you for dealing with TRILOK JEWELLERS',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9.5)),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#3E2723')),
      ),
    );
  }

  static pw.Widget _buildCell(String text, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );
  }

  static Future<void> printPdf(AlterationEntry record) async {
    final pdfBytes = await generate(record);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${record.voucherNo}_alteration_entry',
    );
  }

  static Future<Uint8List> generateBill(AlterationBill bill) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Banner
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#3E2723'),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'TRILOK JEWELLERS',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'Premium Gold & Diamond Jewellery',
                          style: const pw.TextStyle(
                            color: PdfColors.amber100,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.amber800,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'ALTERATION BILL',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Transaction Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(4),
                  color: PdfColor.fromHex('#FCFAF5'),
                ),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Bill No:', bill.billNo),
                          _buildInfoRow('Bill Date:', dateFormat.format(bill.billDate)),
                          _buildInfoRow('Customer Name:', bill.customerName),
                          _buildInfoRow('Salesman:', bill.salesman.isEmpty ? '-' : bill.salesman),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Bill Type:', bill.billType),
                          _buildInfoRow('Original Job Ref:', bill.originalJobRef),
                          _buildInfoRow('Payment Mode:', bill.paymentMode.isEmpty ? '-' : bill.paymentMode),
                          if (bill.paymentReference.isNotEmpty)
                            _buildInfoRow('Ref No:', bill.paymentReference),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Item Details Section
              pw.Text(
                'BILL LINE ITEMS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E2723'),
                ),
              ),
              pw.SizedBox(height: 8),

              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(1.5),
                  4: const pw.FlexColumnWidth(1.5),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F0E8')),
                    children: [
                      _buildHeaderCell('Item Name'),
                      _buildHeaderCell('Pcs'),
                      _buildHeaderCell('Gross Wt (g)'),
                      _buildHeaderCell('Net Wt (g)'),
                      _buildHeaderCell('Fine Wt (g)'),
                      _buildHeaderCell('Extra Gold (g)'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCell(bill.itemName),
                      _buildCell(bill.pcs.toString(), align: pw.TextAlign.center),
                      _buildCell(bill.grossWt.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(bill.netWt.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(bill.fineWt.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(bill.extraGoldAdded.toStringAsFixed(3), align: pw.TextAlign.right),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // Charges Breakdown
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (bill.narration.isNotEmpty) ...[
                          pw.Text('NARRATION:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                          pw.Text(bill.narration, style: const pw.TextStyle(fontSize: 8.5)),
                          pw.SizedBox(height: 8),
                        ],
                        pw.Text('LABOUR DETAILS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5)),
                        pw.Text('Type: ${bill.labourType} | Rate: ${bill.labourRate.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius: pw.BorderRadius.circular(4),
                        color: PdfColor.fromHex('#FCFAF5'),
                      ),
                      child: pw.Column(
                        children: [
                          _buildSummaryRow('Labour Amount:', bill.labourAmount),
                          _buildSummaryRow('Metal Amount:', bill.metalAmount),
                          if (bill.wastagePer > 0)
                            _buildSummaryRow('Wastage Weight:', bill.wastageWt),
                          if (bill.diamondAmt > 0)
                            _buildSummaryRow('Diamond Amt:', bill.diamondAmt),
                          if (bill.stoneAmt > 0)
                            _buildSummaryRow('Stone Amt:', bill.stoneAmt),
                          if (bill.otherCharges > 0)
                            _buildSummaryRow('Other Charges:', bill.otherCharges),
                          pw.Divider(color: PdfColors.grey400),
                          _buildSummaryRow('Sub-total:', bill.labourAmount + bill.metalAmount + bill.diamondAmt + bill.stoneAmt + bill.otherCharges, isBold: true),
                          if (bill.taxScheme == 'CGST + SGST (Local)') ...[
                            _buildSummaryRow('CGST 9%:', bill.cgstAmount),
                            _buildSummaryRow('SGST 9%:', bill.sgstAmount),
                          ] else ...[
                            _buildSummaryRow('IGST 18%:', bill.igstAmount),
                          ],
                          pw.Divider(color: PdfColors.grey400),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('Net Payable:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                              pw.Text('₹${bill.netAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.SizedBox(height: 20),
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Thank you for dealing with TRILOK JEWELLERS',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryRow(String label, double val, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text('₹${val.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<void> printBillPdf(AlterationBill bill) async {
    final pdfBytes = await generateBill(bill);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${bill.billNo}_alteration_bill',
    );
  }
}
