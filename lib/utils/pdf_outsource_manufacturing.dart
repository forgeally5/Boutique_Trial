import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../views/transactions/j_outsource_manufacturing/outsource_manufacturing_model.dart';

class PdfOutsourceManufacturing {
  static Future<Uint8List> generate(OutsourceManufacturing record) async {
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
                          'Outsource Manufacturing & Job Work Vouchers',
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
                          fontSize: 11,
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
                          _buildInfoRow('Artisan Name:', record.artisanName),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('Transaction Type:', record.transactionType),
                          _buildInfoRow('Reference/Order No:', record.referenceNo.isEmpty ? '-' : record.referenceNo),
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
                  ...record.items.map((item) => pw.TableRow(
                    children: [
                      _buildCell(item.itemName),
                      _buildCell(item.quantity.toString(), align: pw.TextAlign.center),
                      _buildCell(item.grossWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(item.stoneWeight.toStringAsFixed(3), align: pw.TextAlign.right),
                      _buildCell(item.netWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                      _buildCell(item.purity.toStringAsFixed(1), align: pw.TextAlign.center),
                      _buildCell(item.fineWeight.toStringAsFixed(3), align: pw.TextAlign.right, isBold: true),
                    ],
                  )),
                ],
              ),
              pw.SizedBox(height: 20),

              // Summary & Formula Explanation
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#FFF8E1'),
                  border: pw.Border.all(color: PdfColors.amber200),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Calculation Summary:',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Total Quantity = ${record.totalQuantity} pcs',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Total Gross Weight = ${record.totalGrossWeight.toStringAsFixed(3)} g',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Total Net Weight = ${record.totalNetWeight.toStringAsFixed(3)} g',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text(
                      'Total Fine Weight = ${record.totalFineWeight.toStringAsFixed(3)} g',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),

              if (record.remarks.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'Remarks / Notes: ${record.remarks}',
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
                      pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)))),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Dispatcher', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Trilok Store', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)))),
                      pw.SizedBox(height: 4),
                      pw.Text('Artisan / Goldsmith', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('(${record.artisanName})', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.8)))),
                      pw.SizedBox(height: 4),
                      pw.Text('Manager Approval', style: const pw.TextStyle(fontSize: 9)),
                      pw.Text('Job Department', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printPdf(OutsourceManufacturing record) async {
    final pdfBytes = await generate(record);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Job_${record.transactionNo}',
    );
  }

  static pw.Widget _buildInfoRow(String label, String val) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Text(val, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String label) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        label,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#3E2723')),
      ),
    );
  }

  static pw.Widget _buildCell(String val, {pw.TextAlign align = pw.TextAlign.left, bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        val,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}