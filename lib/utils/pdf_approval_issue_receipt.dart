import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/transactions/m_approval_issue_receipt/approval_issue_receipt_model.dart';

class PdfApprovalIssueReceipt {
  static Future<Uint8List> generate(ApprovalIssueReceipt record) async {
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
                          'Hallmarking & Assay Testing Centre Certificate',
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
                        color: PdfColors.deepOrange800,
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
                          _buildInfoRow('Assay/Approval Centre:', record.approvalCentre),
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

              // Item Table Header
              pw.Text(
                'ITEM & PURITY BREAKDOWN',
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
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FlexColumnWidth(2),
                  5: const pw.FlexColumnWidth(2),
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
                      _buildHeaderCell('Original Purity'),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      _buildCell(record.itemName),
                      _buildCell(record.quantity.toString(), align: pw.TextAlign.center),
                      _buildCell(record.grossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.stoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(record.netWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(record.originalPurity.toStringAsFixed(1), align: pw.TextAlign.center),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Assay & Approved Purity Analysis Section
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F3E5F5'),
                  border: pw.Border.all(color: PdfColor.fromHex('#E1BEE7')),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ASSAY TESTING & PURITY VERIFICATION',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10.5, color: PdfColor.fromHex('#4A148C')),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        _buildAnalysisBox('Original Purity', record.originalPurity.toStringAsFixed(1)),
                        _buildAnalysisBox('Approved Purity', record.approvedPurity.toStringAsFixed(1), isHighlight: true),
                        _buildAnalysisBox('Original Fine Wt', '${record.originalFineWeight.toStringAsFixed(3)} g'),
                        _buildAnalysisBox('Approved Fine Wt', '${record.approvedFineWeight.toStringAsFixed(3)} g'),
                        _buildAnalysisBox('Difference', '${record.difference.toStringAsFixed(3)} g'),
                      ],
                    ),
                    if (record.assayResult.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'Assay Result / Certificate: ${record.assayResult}',
                          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.purple900),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              if (record.remarks.isNotEmpty) ...[
                pw.Text(
                  'Remarks: ${record.remarks}',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
                ),
              ],

              pw.Spacer(),

              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                      pw.SizedBox(height: 4),
                      pw.Text('Assay Centre Incharge', style: const pw.TextStyle(fontSize: 10)),
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
                  'TRILOK JEWELLERS — APPROVAL & ASSAY TESTING VOUCHER',
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
            width: 120,
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: isHighlight ? PdfColor.fromHex('#EDE7F6') : PdfColors.white,
        border: pw.Border.all(color: isHighlight ? PdfColors.purple300 : PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 2),
          pw.Text(
            val,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: isHighlight ? PdfColors.purple900 : PdfColor.fromHex('#3E2723'),
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

  static Future<void> printPdf(ApprovalIssueReceipt record) async {
    final pdfBytes = await generate(record);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${record.transactionNo}_approval_entry',
    );
  }
}
