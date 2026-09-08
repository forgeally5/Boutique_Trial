import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DeliveryChallanSummaryItem {
  final String sNo;
  final String date;
  final String description;
  final String consigneeName;
  final String gstin;
  final String soldWt;
  final String invoiceNo;
  final String taxableValue;
  final String sgst;
  final String cgst;
  final String igst;
  final String total;

  DeliveryChallanSummaryItem({
    required this.sNo,
    required this.date,
    required this.description,
    required this.consigneeName,
    required this.gstin,
    required this.soldWt,
    required this.invoiceNo,
    required this.taxableValue,
    required this.sgst,
    required this.cgst,
    required this.igst,
    required this.total,
  });
}

class DeliveryChallanPrintData {
  final String challanNo;
  final String date;

  // Consignee Info
  final String consigneeName;
  final String consigneeAddress;
  final String consigneeGstin;

  // Fixed Top Details
  final String descGoodsHsn;
  final String quantityGoods;
  final String valueGoods;
  final String purposeTransport;
  final String personCarrying;
  final String transportDetails;
  final String destinationDetails;

  // Summary Rows
  final List<DeliveryChallanSummaryItem> summaryItems;

  // Bottom Section
  final String openingStock;
  final String totalSale;

  DeliveryChallanPrintData({
    required this.challanNo,
    required this.date,
    required this.consigneeName,
    required this.consigneeAddress,
    required this.consigneeGstin,
    required this.descGoodsHsn,
    required this.quantityGoods,
    required this.valueGoods,
    required this.purposeTransport,
    required this.personCarrying,
    required this.transportDetails,
    required this.destinationDetails,
    required this.summaryItems,
    required this.openingStock,
    required this.totalSale,
  });
}

class PdfDeliveryChallanApi {
  static Future<Uint8List> generate(
    DeliveryChallanPrintData data, {
    PdfPageFormat format = PdfPageFormat.a4,
  }) async {
    final pdf = pw.Document();

    // Dedicated A4 Landscape print format
    final pageFormat = (format == PdfPageFormat.a4)
        ? PdfPageFormat.a4.landscape
        : format.landscape;

    final int itemsPerPage = 4;
    List<List<DeliveryChallanSummaryItem?>> chunks = [];

    // Filter out empty rows that might have been passed from the UI
    final validItems = data.summaryItems.where((item) {
      return item.date.trim().isNotEmpty ||
          item.description.trim().isNotEmpty ||
          item.soldWt.trim().isNotEmpty ||
          item.invoiceNo.trim().isNotEmpty ||
          item.taxableValue.trim().isNotEmpty ||
          item.total.trim().isNotEmpty;
    }).toList();

    if (validItems.isEmpty) {
      chunks.add([]);
    } else {
      for (int i = 0; i < validItems.length; i += itemsPerPage) {
        int end = (i + itemsPerPage < validItems.length)
            ? i + itemsPerPage
            : validItems.length;
        List<DeliveryChallanSummaryItem?> chunk = List.from(validItems.sublist(i, end));
        
        chunks.add(chunk);
      }
    }

    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          build: (pw.Context context) {
            return pw.SizedBox(
              width: pageFormat.availableWidth,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  // ── Top Header Section ─────────────────────────────────
                  _buildHeader(data),
                  pw.SizedBox(height: 6),

                  // ── Top Details Grid ───────────────────────────────────
                  _buildTopDetailsTable(data),
                  pw.SizedBox(height: 8),

                  // ── Summary Table ──────────────────────────────────────
                  _buildSummarySection(chunk),
                  pw.SizedBox(height: 8),

                  // ── Bottom Declaration & Signature ─────────────────────
                  _buildBottomSection(data),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ── Document Header ────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(DeliveryChallanPrintData data) {
    return pw.Column(
      children: [
        // Tag top right
        pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text(
            '[Original]',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.black,
            ),
          ),
        ),

        // Company Branding (TRILOK with OM SRI JEWEL subtitle)
        pw.Text(
          'TRILOK',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 22,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 4.0,
            color: PdfColor.fromHex('3E2723'),
          ),
        ),
        pw.SizedBox(height: 1.5),
        pw.Text(
          'OM SRI JEWEL',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 3.5,
            color: PdfColor.fromHex('8D6E63'),
          ),
        ),
        pw.SizedBox(height: 3),

        // Address Line
        pw.Text(
          '123, 1st floor, SABARI DURGH TOWERS,VYSIAL STREET,, COIMBATORE- 641001.',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(
            fontSize: 9.5,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 1),

        // State Details
        pw.Text(
          'State Name: Tamil Nadu   State Code: 33',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 5),

        // Title Banner Box
        pw.Container(
          width: 220,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1.0),
          ),
          child: pw.Text(
            'DELIVERY CHALLAN',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        pw.SizedBox(height: 6),

        // Challan No & Date Line
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'No : ${data.challanNo}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              'Date : ${data.date}',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Top Details Grid ───────────────────────────────────────────────────────
  static pw.Widget _buildTopDetailsTable(DeliveryChallanPrintData data) {
    const tableBorderColor = PdfColors.black;

    return pw.Table(
      border: pw.TableBorder.all(color: tableBorderColor, width: 0.8),
      columnWidths: const {
        0: pw.FixedColumnWidth(240),
        1: pw.FlexColumnWidth(),
      },
      children: [
        // Row 1: Consignee Info
        pw.TableRow(
          children: [
            // Left Cell
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '1. Name of the Consignee',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '   Address & GSTIN',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Right Cell
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        data.consigneeName,
                        style: pw.TextStyle(
                          fontSize: 9.5,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (data.consigneeGstin.isNotEmpty)
                        pw.Text(
                          'GSTIN : ${data.consigneeGstin}',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  if (data.consigneeAddress.isNotEmpty) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      data.consigneeAddress,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),

        _buildGridPdfTableRow('3.', 'Description of Goods & HSN Code', data.descGoodsHsn),
        _buildGridPdfTableRow('4.', 'Quantity of Goods', data.quantityGoods),
        _buildGridPdfTableRow('5.', 'Value of Goods', data.valueGoods),
        _buildGridPdfTableRow('6.', 'Purpose of Transport', data.purposeTransport),
        _buildGridPdfTableRow('7.', 'Name of the person who carrying the Goods', data.personCarrying),
        _buildGridPdfTableRow('8.', 'Transport Details', data.transportDetails),
        _buildGridPdfTableRow('9.', 'Destination Details & Intra or Inter State', data.destinationDetails),
      ],
    );
  }

  static pw.TableRow _buildGridPdfTableRow(String num, String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
          child: pw.Text(
            '$num $label',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          child: pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 9.5,
            ),
          ),
        ),
      ],
    );
  }

  // ── Summary Table ──────────────────────────────────────────────────────────
  static pw.Widget _buildSummarySection(List<DeliveryChallanSummaryItem?> items) {
    const tableBorderColor = PdfColors.black;

    return pw.Column(
      children: [
        // Banner Header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 3.5),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: tableBorderColor, width: 0.8),
            color: PdfColor.fromHex('F0F0F0'),
          ),
          child: pw.Text(
            'SUMMARY',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),

        // Summary Grid Table
        pw.Table(
          border: pw.TableBorder.all(color: tableBorderColor, width: 0.8),
          columnWidths: const {
            0: pw.FixedColumnWidth(32),
            1: pw.FixedColumnWidth(70),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FixedColumnWidth(55),
            4: pw.FixedColumnWidth(65),
            5: pw.FixedColumnWidth(65),
            6: pw.FixedColumnWidth(50),
            7: pw.FixedColumnWidth(50),
            8: pw.FixedColumnWidth(50),
            9: pw.FixedColumnWidth(65),
          },
          children: [
            // Header Row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.white),
              children: [
                _buildPdfCell('S.No', isHeader: true),
                _buildPdfCell('Date', isHeader: true),
                _buildPdfCell('Description', isHeader: true),
                _buildPdfCell('Sold Wt', isHeader: true),
                _buildPdfCell('Invoice No', isHeader: true),
                _buildPdfCell('Taxable Value', isHeader: true),
                _buildPdfCell('SGST 1.5%', isHeader: true),
                _buildPdfCell('CGST 1.5%', isHeader: true),
                _buildPdfCell('IGST 3%', isHeader: true),
                _buildPdfCell('Total', isHeader: true),
              ],
            ),

            // Data Rows
            ...items.map((item) {
              if (item == null) {
                return pw.TableRow(
                  children: List.generate(10, (index) => _buildPdfCell(' ')),
                );
              }
              return pw.TableRow(
                children: [
                  _buildPdfCell(item.sNo),
                  _buildPdfCell(item.date),
                  _buildPdfCell(item.description),
                  _buildPdfCell(item.soldWt),
                  _buildPdfCell(item.invoiceNo),
                  _buildPdfCell(item.taxableValue),
                  _buildPdfCell(item.sgst),
                  _buildPdfCell(item.cgst),
                  _buildPdfCell(item.igst),
                  _buildPdfCell(item.total),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: isHeader ? 8.5 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  // ── Bottom Declaration Section ─────────────────────────────────────────────
  static pw.Widget _buildBottomSection(DeliveryChallanPrintData data) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // Opening Stock & Total Sale
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Opening Stock : ${data.openingStock}',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Total Sale : ${data.totalSale}',
              style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
        pw.SizedBox(height: 6),

        // Certifications
        pw.Text(
          'I/We Certify that the above particulars are true and correct to the best of my / our knowledge',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Selected samples will be hallmarked and Billed',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),

        // Signatures & E-Way Note
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            // Left Signature
            pw.Column(
              children: [
                pw.Container(
                  width: 130,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Signature Agent / Staff',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),

            // E-Way Note
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                child: pw.Text(
                  'Note : No E-way bill is required to be generated as the Goods covered under this invoice are exempted as per Serial No. 150 / 151 to the Annexure to Rule 138(14) of the CGST Rules 2017',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
                ),
              ),
            ),

            // Right Signature
            pw.Column(
              children: [
                pw.Text(
                  'For OM SRI JEWEL',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 16),
                pw.Container(
                  width: 130,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
                    ),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Authorised Signatory',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
