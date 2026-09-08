import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfOrderEntryApi {
  static const PdfColor _black = PdfColor.fromInt(0xFF000000);
  static const PdfColor _grey = PdfColor.fromInt(0xFF666666);

  static Future<void> printOrder(Map<String, dynamic> order) async {
    final bytes = await _buildPdf(order: order);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Order_${order['voucherNo'] ?? 'Entry'}',
    );
  }

  static Future<Uint8List> _buildPdf({required Map<String, dynamic> order}) async {
    final pdf = pw.Document();

    String businessName = 'TRILOK';
    String subtitle = 'OM SRI JEWEL';
    String address = '';

    try {
      final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        businessName = doc.data()!['businessName']?.toString() ?? businessName;
        subtitle = doc.data()!['subtitle']?.toString() ?? subtitle;
        address = doc.data()!['address']?.toString() ?? address;
      }
    } catch (_) {}

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- Header ---
              pw.Center(
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.0,
                    color: _black,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                    color: _grey,
                  ),
                ),
              ),
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    address,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10, color: _black),
                  ),
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _black, width: 1),
                  ),
                  child: pw.Text(
                    'CUSTOMER ORDER',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // --- Order Info ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Voucher No:', order['voucherNo']?.toString() ?? '—'),
                      _buildInfoRow('Date:', order['voucherDate']?.toString() ?? '—'),
                      _buildInfoRow('Customer Name:', order['customerName']?.toString() ?? '—'),
                      _buildInfoRow('Salesman:', order['salesmanName']?.toString() ?? order['salesman']?.toString() ?? '—'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Delivery Date:', order['deliveryDate']?.toString() ?? '—'),
                      _buildInfoRow('Status:', order['status']?.toString() ?? '—'),
                      _buildInfoRow('Process:', order['subType']?.toString() ?? order['process']?.toString() ?? '—'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // --- Item Details Table ---
              pw.Text('Item Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: _black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                },
                headers: ['Item Name', 'Pcs', 'Gross Wt', 'Net Wt', 'Purity', 'Total Amt'],
                data: [
                  [
                    order['itemName']?.toString() ?? '—',
                    order['pcs']?.toString() ?? '1',
                    order['grossWt']?.toString() ?? '0.000',
                    order['netWt']?.toString() ?? '0.000',
                    order['purity']?.toString() ?? '0.0',
                    order['billAmount']?.toString() ?? order['totalAmount']?.toString() ?? '0.00',
                  ],
                ],
              ),
              pw.SizedBox(height: 24),

              // --- Payment Info ---
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _buildTotalRow('Bill Amount:', order['billAmount']?.toString() ?? order['totalAmount']?.toString() ?? '0.00'),
                        _buildTotalRow('Advance Paid:', order['advanceAmount']?.toString() ?? order['receivedAmt']?.toString() ?? '0.00'),
                      ],
                    ),
                  ),
                ],
              ),
              if (order['narration'] != null && order['narration'].toString().isNotEmpty) ...[
                pw.SizedBox(height: 24),
                pw.Text('Remarks: ${order['narration']}', style: const pw.TextStyle(fontSize: 10)),
              ],

              // --- Signatures ---
              pw.Spacer(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  static Future<void> printAdvance(Map<String, dynamic> item) async {
    final bytes = await _buildAdvancePdf(item: item);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Gold_Rate_Fixing_Advance_${item['receiptNo'] ?? 'Voucher'}',
    );
  }

  static Future<Uint8List> _buildAdvancePdf({required Map<String, dynamic> item}) async {
    final pdf = pw.Document();

    String businessName = 'TRILOK';
    String subtitle = 'OM SRI JEWEL';
    String address = '';

    try {
      final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        businessName = doc.data()!['businessName']?.toString() ?? businessName;
        subtitle = doc.data()!['subtitle']?.toString() ?? subtitle;
        address = doc.data()!['address']?.toString() ?? address;
      }
    } catch (_) {}

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.0,
                    color: _black,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                    color: _grey,
                  ),
                ),
              ),
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    address,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10, color: _black),
                  ),
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _black, width: 1),
                  ),
                  child: pw.Text(
                    'GOLD RATE FIXING ADVANCE RECEIPT',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Receipt No:', item['receiptNo']?.toString() ?? '—'),
                      _buildInfoRow('Date:', item['date']?.toString() ?? '—'),
                      _buildInfoRow('Customer Name:', item['customerName']?.toString() ?? '—'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Payment Mode:', item['paymentMode']?.toString() ?? 'Cash'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Advance details table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: _black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                },
                headers: ['Description', 'Fixed Rate/gm', 'Fixed Weight (g)', 'Advance Amount'],
                data: [
                  [
                    'Gold Rate Fixing Advance',
                    '₹${item['fixedRate']?.toString() ?? '0.00'}',
                    '${item['fixedWeight']?.toString() ?? '0.000'} g',
                    '₹${item['amount']?.toString() ?? '0.00'}',
                  ],
                ],
              ),
              pw.SizedBox(height: 24),

              // Remarks
              if (item['narration'] != null && item['narration'].toString().isNotEmpty) ...[
                pw.Text('Remarks: ${item['narration']}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 24),
              ],

              pw.Spacer(),
              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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

  static Future<void> printRefund(Map<String, dynamic> item) async {
    final bytes = await _buildRefundPdf(item: item);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Advance_Refund_${item['receiptNo'] ?? 'Voucher'}',
    );
  }

  static Future<Uint8List> _buildRefundPdf({required Map<String, dynamic> item}) async {
    final pdf = pw.Document();

    String businessName = 'TRILOK';
    String subtitle = 'OM SRI JEWEL';
    String address = '';

    try {
      final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        businessName = doc.data()!['businessName']?.toString() ?? businessName;
        subtitle = doc.data()!['subtitle']?.toString() ?? subtitle;
        address = doc.data()!['address']?.toString() ?? address;
      }
    } catch (_) {}

    final pageFormat = PdfPageFormat.a4;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Center(
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 2.0,
                    color: _black,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  subtitle,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1.5,
                    color: _grey,
                  ),
                ),
              ),
              if (address.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    address,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 10, color: _black),
                  ),
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: _black, width: 1),
                  ),
                  child: pw.Text(
                    'ADVANCE REFUND VOUCHER',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

              // Details
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Voucher No:', item['receiptNo']?.toString() ?? '—'),
                      _buildInfoRow('Date:', item['date']?.toString() ?? '—'),
                      _buildInfoRow('Customer Name:', item['customerName']?.toString() ?? '—'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Payment Mode:', item['paymentMode']?.toString() ?? 'Cash'),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // Refund details table
              pw.TableHelper.fromTextArray(
                border: pw.TableBorder.all(color: _black, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                cellStyle: const pw.TextStyle(fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignment: pw.Alignment.centerRight,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                },
                headers: ['Description', 'Refund Amount'],
                data: [
                  [
                    'Advance Refund Payment',
                    '₹${item['amount']?.toString() ?? '0.00'}',
                  ],
                ],
              ),
              pw.SizedBox(height: 24),

              // Remarks
              if (item['narration'] != null && item['narration'].toString().isNotEmpty) ...[
                pw.Text('Remarks: ${item['narration']}', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 24),
              ],

              pw.Spacer(),
              // Signatures
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Customer Signature', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Container(width: 120, height: 1, color: _black),
                      pw.SizedBox(height: 4),
                      pw.Text('Authorized Signatory', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
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
}
