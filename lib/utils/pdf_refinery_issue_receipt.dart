import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/transactions/l_refinery_issue_receipt/refinery_issue_receipt_model.dart';

class PdfRefineryIssueReceipt {
  static Future<Uint8List> generate(RefineryIssueReceipt record) async {
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
                          'Refinery Operations & Process Vouchers',
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
                        color: PdfColors.brown800,
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
                          _buildInfoRow('Transaction No:', record.transactionNo),
                          _buildInfoRow('Date:', dateFormat.format(record.date)),
                          _buildInfoRow('Refinery Name:', record.refineryName),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Transaction Type:', record.transactionType),
                          _buildInfoRow('Ref. Issue No:', record.referenceIssueNo.isEmpty ? '-' : record.referenceIssueNo),
                          _buildInfoRow('Status:', record.status),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Table for Issue Details
              pw.Text(
                'ISSUED ITEM DETAILS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#3E2723'),
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(1.5),
                  6: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F4F0E8')),
                    children: [
                      _buildHeaderCell('Item Name'),
                      _buildHeaderCell('Qty'),
                      _buildHeaderCell('Gross Wt (g)'),
                      _buildHeaderCell('Stone Wt (g)'),
                      _buildHeaderCell('Net Wt (g)'),
                      _buildHeaderCell('Purity'),
                      _buildHeaderCell('Fine Wt (g)'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCell(record.itemName),
                      _buildCell(record.quantity.toString(), align: pw.TextAlign.center),
                      _buildCell(record.grossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.stoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.netWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(record.purity.toStringAsFixed(1), align: pw.TextAlign.center),
                      _buildCell(record.fineWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Received Item Details Table (only for Receipts)
              if (!record.isIssue) ...[
                pw.Text(
                  'RECEIVED ITEM DETAILS',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#3E2723'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(1.5),
                    5: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#E8F5E9')),
                      children: [
                        _buildHeaderCell('Item Name'),
                        _buildHeaderCell('Rec. Gross Wt (g)'),
                        _buildHeaderCell('Rec. Other Wt (g)'),
                        _buildHeaderCell('Rec. Net Wt (g)'),
                        _buildHeaderCell('Rec. Purity'),
                        _buildHeaderCell('Rec. Fine Wt (g)'),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        _buildCell('Refined Gold (Pure Bar)'),
                        _buildCell(record.receivedGrossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                        _buildCell(record.receivedStoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                        _buildCell(record.receivedNetWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                        _buildCell(record.receivedPurity.toStringAsFixed(1), align: pw.TextAlign.center),
                        _buildCell(record.receivedFineWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),
              ],

              // Process Loss & Differences Card if Receipt
              if (!record.isIssue) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EFEBE9'),
                    border: pw.Border.all(color: PdfColor.fromHex('#D7CCC8')),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'PROCESS ANALYSIS & YIELD SUMMARY',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#3E2723')),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          _buildAnalysisBox('Issued Fine Weight', '${record.issuedFineWeight.toStringAsFixed(3)} g'),
                          _buildAnalysisBox('Received Fine Weight', '${record.receivedFineWeight.toStringAsFixed(3)} g'),
                          _buildAnalysisBox('Melting Loss / Diff', '${record.lossDifference.toStringAsFixed(3)} g', isHighlight: true),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),

                // Financial Details Card
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#ECEFF1'),
                    border: pw.Border.all(color: PdfColor.fromHex('#CFD8DC')),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'REFINING CHARGES & PAYMENTS',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColor.fromHex('#3E2723')),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildSummaryText("Today's Gold Rate:", '₹${record.goldRate.toStringAsFixed(2)} /g'),
                                _buildSummaryText('Loss Value:', '₹${record.lossGainAmount.toStringAsFixed(2)}'),
                                _buildSummaryText('Charge Type:', record.refiningChargeType),
                              ],
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                _buildSummaryText('Service Charge:', '₹${record.refiningServiceAmount.toStringAsFixed(2)} (@ ₹${record.refiningServiceRate.toStringAsFixed(2)}/g)'),
                                _buildSummaryText('GST (${record.taxPercentage}%):', '₹${record.taxAmount.toStringAsFixed(2)}'),
                                _buildSummaryText('Net Payable:', '₹${record.netAmount.toStringAsFixed(2)}', isBold: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),
              ],

              if (record.remarks.isNotEmpty) ...[
                pw.Text(
                  'Remarks: ${record.remarks}',
                  style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
                ),
              ],

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Refinery Representative', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    children: [
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
                  'TRILOK JEWELLERS — REFINERY OPERATIONS VOUCHER',
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

  static pw.Widget _buildAnalysisBox(String title, String val, {bool isHighlight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: pw.BoxDecoration(
        color: isHighlight ? PdfColor.fromHex('#FFEBEE') : PdfColors.white,
        border: pw.Border.all(color: isHighlight ? PdfColors.red300 : PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: isHighlight ? PdfColors.red900 : PdfColor.fromHex('#3E2723'),
            ),
          ),
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

  static Future<void> printPdf(RefineryIssueReceipt record) async {
    final pdfBytes = await generate(record);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${record.transactionNo}_refinery_entry',
    );
  }

  static pw.Widget _buildSummaryText(String label, String val, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
          ),
          pw.SizedBox(width: 4),
          pw.Text(
            val,
            style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
