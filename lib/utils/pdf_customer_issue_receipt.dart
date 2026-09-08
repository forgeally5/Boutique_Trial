import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/transactions/k_customer_issue_receipt/customer_issue_receipt_model.dart';

class PdfCustomerIssueReceipt {
  static Future<Uint8List> generate(CustomerIssueReceipt record) async {
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
                          _buildInfoRow('Transaction No:', record.transactionNo),
                          _buildInfoRow('Date:', dateFormat.format(record.date)),
                          _buildInfoRow('Customer Name:', record.customerName),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Transaction Type:', record.transactionType),
                          _buildInfoRow('Reference No:', record.referenceNo.isEmpty ? '-' : record.referenceNo),
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
                  6: const pw.FlexColumnWidth(2),
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
                      _buildHeaderCell('Rate'),
                      _buildHeaderCell('Amount'),
                    ],
                  ),
                  ...record.items.map((i) => pw.TableRow(
                    children: [
                      _buildCell(i.tagId),
                      _buildCell(i.itemName),
                      _buildCell(i.grossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(i.stoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(i.netWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(i.ratePerGram.toStringAsFixed(2), align: pw.TextAlign.right),
                      _buildCell(i.amount.toStringAsFixed(2), align: pw.TextAlign.right, isBold: true),
                    ],
                  )),
                  // Totals Row
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColor.fromHex('#FCFAF5')),
                    children: [
                      _buildCell('TOTAL', isBold: true, align: pw.TextAlign.center),
                      _buildCell(''),
                      _buildCell(record.totalGrossWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(''),
                      _buildCell(record.totalNetWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(''),
                      _buildCell('Rs. ${record.totalAmount.toStringAsFixed(2)}', align: pw.TextAlign.right, isBold: true),
                    ]
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              if (!record.isIssue) ...[
                // Payment Summary
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#E8F5E9'),
                    border: pw.Border.all(color: PdfColors.green200),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Payment Settlement:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Cash: Rs. ${record.paymentCash.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Bank: Rs. ${record.paymentBank.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('Card: Rs. ${record.paymentCard.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 9)),
                        ]
                      )
                    ],
                  ),
                ),
                pw.SizedBox(height: 14),
              ],

              if (record.remarks.isNotEmpty || record.termsText.isNotEmpty) ...[
                pw.Text(
                  'Remarks / Terms: ${record.remarks} ${record.termsText}',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
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
                      if (record.isSignedPhysically)
                         pw.Text('(Signed Physically)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                      pw.SizedBox(height: record.isSignedPhysically ? 10 : 20),
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

  static Future<void> printPdf(CustomerIssueReceipt record) async {
    final pdfBytes = await generate(record);
    await Printing.layoutPdf(
      onLayout: (_) async => pdfBytes,
      name: '${record.transactionNo}_customer_entry',
    );
  }
}
