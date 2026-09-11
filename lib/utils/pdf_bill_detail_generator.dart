import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PdfBillDetailGenerator {
  static Future<Uint8List> generate(Map<String, dynamic> docData, Map<String, dynamic>? profileData, bool isSupplier) async {
    final pdf = pw.Document();

    final voucherNo = docData['voucherNo']?.toString() ?? '';
    final billType = docData['billType']?.toString() ?? 'Sale';
    
    // Parse date
    final rawDate = docData['voucherDate'];
    final dateStr = rawDate is Timestamp
        ? DateFormat('dd/MM/yyyy EEE').format(rawDate.toDate())
        : rawDate?.toString() ?? '';

    final acName = docData['acName']?.toString() ?? '';
    final salesman = docData['salesman']?.toString() ?? '';
    final placeOfSupply = docData['placeOfSupply']?.toString() ?? '';
    final dueDate = docData['dueDate']?.toString() ?? '';
    final carat = docData['carat']?.toString() ?? '';
    
    final customerDetails = docData['customerDetails'] as Map?;
    final gstin = customerDetails?['gstin']?.toString() ??
        docData['gstinNo']?.toString() ??
        docData['gstin']?.toString() ??
        '';

    final items = docData['items'] as List? ?? [];

    // Formatter helpers
    String formatAmt(dynamic val) {
      if (val == null) return '0.00';
      final d = (val as num?)?.toDouble() ?? 0.0;
      return d.toStringAsFixed(2);
    }

    String formatWt(dynamic val) {
      if (val == null) return '0.000';
      final d = (val as num?)?.toDouble() ?? 0.0;
      return d.toStringAsFixed(3);
    }

    // Build the first part: Bill details (Page 1)
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 32,
                  height: 32,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.brown900,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Center(
                    child: pw.Text('F', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('FORGEALLY BOUTIQUE', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, letterSpacing: 2.5, color: PdfColors.brown900)),
                pw.Text('BOUTIQUE RETAIL', style: pw.TextStyle(fontSize: 9, letterSpacing: 2, color: PdfColors.brown700)),
                pw.SizedBox(height: 3),
                pw.Text('NSR ROAD, SAI BABA COLONY, COIMBATORE - 641001', style: const pw.TextStyle(fontSize: 7)),
                pw.SizedBox(height: 8),
                pw.Container(height: 1.5, color: PdfColors.brown900),
                pw.SizedBox(height: 6),
                pw.Text('VOUCHER DETAILS: $voucherNo ($billType)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                pw.SizedBox(height: 12),
              ],
            ),

            // General Info Block
            pw.Text('GENERAL INFORMATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow(isSupplier ? 'Supplier Name' : 'Customer Name', acName)),
                      pw.Expanded(child: _buildPdfInfoRow('Voucher No', voucherNo)),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Voucher Date', dateStr)),
                      pw.Expanded(child: _buildPdfInfoRow('GSTIN / Tax ID', gstin.isNotEmpty ? gstin : 'N/A')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Salesman', salesman.isNotEmpty ? salesman : 'N/A')),
                      pw.Expanded(child: _buildPdfInfoRow('Place of Supply', placeOfSupply.isNotEmpty ? placeOfSupply : 'N/A')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Due Date', dueDate.isNotEmpty ? dueDate : 'N/A')),
                      pw.Expanded(child: _buildPdfInfoRow('Purity / Carat', carat.isNotEmpty ? carat : 'N/A')),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Items breakdown
            pw.Text('ITEMS BREAKDOWN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
            pw.SizedBox(height: 4),
            _buildPdfItemsTable(items, formatWt, formatAmt),
            pw.SizedBox(height: 12),

            // Payment Details
            pw.Text('PAYMENT & BOTTOM PANEL DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
            pw.SizedBox(height: 4),
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Cash Amount Paid', 'Rs. ${formatAmt(docData['cashAmt'])}')),
                      pw.Expanded(child: _buildPdfInfoRow('Bank Amount Paid', 'Rs. ${formatAmt(docData['bankAmt'])}${docData['bankName'] != null && docData['bankName'].toString().isNotEmpty ? ' (${docData['bankName']})' : ''}')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Card Amount Paid', 'Rs. ${formatAmt(docData['cardAmt'])}${docData['cardMachine'] != null && docData['cardMachine'].toString().isNotEmpty ? ' (${docData['cardMachine']})' : ''}')),
                      pw.Expanded(child: _buildPdfInfoRow('Old Gold Purchase Amt', 'Rs. ${formatAmt(docData['ogPurchaseAmt'])}')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Sales Return Amt', 'Rs. ${formatAmt(docData['salesReturnAmt'])}')),
                      pw.Expanded(child: _buildPdfInfoRow('Gold Scheme Amt', 'Rs. ${formatAmt(docData['goldSchemeAmt'])}')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Rate Apply Amt', 'Rs. ${formatAmt(docData['rateApplyAmt'])}')),
                      pw.Expanded(child: _buildPdfInfoRow('Metal Settled Weight', '${formatWt(docData['metalSettledWt'])}g')),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    children: [
                      pw.Expanded(child: _buildPdfInfoRow('Rate Difference Amt', 'Rs. ${formatAmt(docData['rateDiffAmt'])}')),
                      pw.Expanded(child: _buildPdfInfoRow('AP Amount', 'Rs. ${formatAmt(docData['apAmt'])}')),
                    ],
                  ),
                  if ((docData['bankChequeNo']?.toString().isNotEmpty ?? false) ||
                      (docData['bankRemarks']?.toString().isNotEmpty ?? false) ||
                      (docData['cardApprovalNo']?.toString().isNotEmpty ?? false) ||
                      (docData['cardRemarks']?.toString().isNotEmpty ?? false)) ...[
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildPdfInfoRow('Bank Cheque/Ref No.', docData['bankChequeNo']?.toString() ?? 'N/A')),
                        pw.Expanded(child: _buildPdfInfoRow('Bank Remarks', docData['bankRemarks']?.toString() ?? 'N/A')),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildPdfInfoRow('Card Approval/Ref No.', docData['cardApprovalNo']?.toString() ?? 'N/A')),
                        pw.Expanded(child: _buildPdfInfoRow('Card Remarks', docData['cardRemarks']?.toString() ?? 'N/A')),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Old Gold Metadata
            if (docData['ogGrossWt'] != null && (docData['ogGrossWt'] as num) > 0) ...[
              pw.Text('OLD GOLD METADATA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildPdfInfoRow('OG Gross Weight', '${formatWt(docData['ogGrossWt'])}g')),
                        pw.Expanded(child: _buildPdfInfoRow('OG Dust Weight', '${formatWt(docData['ogDustWt'])}g')),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildPdfInfoRow('OG Net Weight', '${formatWt(docData['ogNetWt'])}g')),
                        pw.Expanded(child: _buildPdfInfoRow('OG Wastage %', '${formatWt(docData['ogWastage'])}%')),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildPdfInfoRow('OG Final Weight', '${formatWt(docData['ogFinalWt'])}g')),
                        pw.Expanded(child: _buildPdfInfoRow('OG Rate Applied', 'Rs. ${formatAmt(docData['ogRate'])}')),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
            ],

            // Narration
            if (docData['narration']?.toString().isNotEmpty ?? false) ...[
              pw.Text('NARRATION', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(docData['narration'].toString(), style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.SizedBox(height: 12),
            ],

            // Financial Summary
            pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
            pw.SizedBox(height: 4),
            _buildPdfFinancialSummary(docData, formatAmt),
          ];
        },
      ),
    );

    // Build the second part: Customer/Supplier Profile Details (Page 2)
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          final title = isSupplier ? 'SUPPLIER PROFILE DETAILS' : 'CUSTOMER PROFILE DETAILS';
          
          if (profileData == null || profileData.isEmpty) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                pw.SizedBox(height: 8),
                pw.Container(height: 1, color: PdfColors.grey400),
                pw.SizedBox(height: 16),
                pw.Text('No registered profile database entry found for "$acName".', style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                pw.SizedBox(height: 14),
                pw.Text('Basic Voucher Account details:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                _buildPdfInfoRow('Name', acName),
                _buildPdfInfoRow('GSTIN / Tax ID', gstin.isNotEmpty ? gstin : 'N/A'),
              ],
            );
          }

          final name = profileData['name']?.toString() ?? 'N/A';
          final code = isSupplier
              ? (profileData['supplierCode'] ?? 'N/A')
              : (profileData['customerCode'] ?? 'N/A');

          // Photo widget
          pw.Widget? photoWidget;
          final photoBase64 = profileData['photoBase64']?.toString() ?? '';
          if (photoBase64.isNotEmpty) {
            try {
              final bytes = base64Decode(photoBase64);
              final image = pw.MemoryImage(bytes);
              photoWidget = pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Image(image, fit: pw.BoxFit.cover),
              );
            } catch (_) {}
          }

          // Address lines
          final block = profileData['blockNo']?.toString() ?? '';
          final building = profileData['buildingName']?.toString() ?? '';
          final street = profileData['street']?.toString() ?? '';
          final area = profileData['area']?.toString() ?? '';
          final city = profileData['city']?.toString() ?? '';
          final zip = profileData['zipCode']?.toString() ?? '';
          final stateVal = profileData['state']?.toString() ?? '';
          final country = profileData['country']?.toString() ?? '';

          final addressLines = [
            [block, building].where((s) => s.isNotEmpty).join(', '),
            street,
            area,
            [city, zip].where((s) => s.isNotEmpty).join(' - '),
            [stateVal, country].where((s) => s.isNotEmpty).join(', '),
          ].where((s) => s.isNotEmpty).toList();

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(title, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                      pw.Text('$name ($code)', style: pw.TextStyle(fontSize: 10, color: PdfColors.brown700)),
                    ],
                  ),
                  photoWidget ?? pw.SizedBox.shrink(),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Container(height: 1.5, color: PdfColors.brown900),
              pw.SizedBox(height: 16),

              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Left column
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CONTACT DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
                        pw.SizedBox(height: 5),
                        _buildPdfField('Primary Mobile', profileData['mobileNo1']),
                        _buildPdfField('Secondary Mobile', profileData['mobileNo2']),
                        _buildPdfField('Phone 1', profileData['phoneNo1']),
                        _buildPdfField('Email', profileData['email1']),
                        pw.SizedBox(height: 16),

                        pw.Text('ADDRESS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
                        pw.SizedBox(height: 5),
                        if (addressLines.isEmpty)
                          pw.Text('No address listed.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))
                        else
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.grey300),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: addressLines.map((line) => pw.Padding(
                                padding: const pw.EdgeInsets.symmetric(vertical: 1),
                                child: pw.Text(line, style: const pw.TextStyle(fontSize: 8)),
                              )).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),

                  // Right column
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REGISTRATION & TAX SETTINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
                        pw.SizedBox(height: 5),
                        _buildPdfField('GSTIN', profileData['gstin']),
                        _buildPdfField('PAN No', profileData['pan']),
                        _buildPdfField('MSME No', profileData['msmeNo']),
                        _buildPdfField('MSME Type', profileData['msmeType']),
                        _buildPdfField('Composition Scheme', profileData['isCompositionScheme'] == true ? 'Yes' : 'No'),
                        pw.SizedBox(height: 16),

                        pw.Text('CREDIT SETTINGS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.brown800)),
                        pw.SizedBox(height: 5),
                        _buildPdfField('Credit Limit', 'Rs. ${formatAmt(profileData['creditLimit'])}'),
                        _buildPdfField('Credit Days', '${profileData['creditDays'] ?? 0} Days'),
                      ],
                    ),
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

  static pw.Widget _buildPdfInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey700)),
            pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 8, color: PdfColors.black)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildPdfField(String label, dynamic val) {
    final text = val?.toString() ?? '';
    if (text.isEmpty || text == 'null' || text == '0') return pw.SizedBox.shrink();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.grey700)),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 8))),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfItemsTable(List itemsList, String Function(dynamic) formatWt, String Function(dynamic) formatAmt) {
    final headers = [
      'Tag No / Style',
      'Item Name',
      'Purity',
      'Pcs',
      'Gross Wt',
      'Net Wt',
      'Rate',
      'Metal Amt',
      'Labour Details',
      'Labour Amt',
      'Total'
    ];

    final List<List<String>> tableData = [];
    
    for (var item in itemsList) {
      final double metalAmt = (item['totMetalAmt'] as num?)?.toDouble() ??
          (item['metalAmt'] as num?)?.toDouble() ?? 0.0;
      final double labourAmt = (item['labourAmt'] as num?)?.toDouble() ?? 0.0;
      final double rowTotal = metalAmt + labourAmt;

      final labourOn = item['labourOn']?.toString() ?? 'Per Piece';
      final double labourRate = (item['labourRate'] as num?)?.toDouble() ?? 0.0;

      String labFormula = '';
      if (labourOn.contains('Net Wt')) {
        labFormula = 'Rs. ${labourRate.toStringAsFixed(2)} /g Net';
      } else if (labourOn.contains('Gross Wt')) {
        labFormula = 'Rs. ${labourRate.toStringAsFixed(2)} /g Gross';
      } else if (labourOn.contains('Percentage')) {
        labFormula = '${labourRate.toStringAsFixed(2)}%';
      } else {
        labFormula = 'Rs. ${labourRate.toStringAsFixed(2)} /pc';
      }

      tableData.add([
        item['tagId']?.toString() ?? 'N/A',
        item['name']?.toString() ?? '',
        item['purity']?.toString() ?? '',
        item['pcs']?.toString() ?? '1',
        '${formatWt(item['grossWeight'])}g',
        '${formatWt(item['netWeight'])}g',
        'Rs. ${formatAmt(item['rate'])}',
        'Rs. ${formatAmt(metalAmt)}',
        '$labFormula ($labourOn)',
        'Rs. ${formatAmt(labourAmt)}',
        'Rs. ${formatAmt(rowTotal)}',
      ]);

      // Check sub-rows/extra charges
      final extraCharges = item['extraCharges'] as List? ?? [];
      if (extraCharges.isNotEmpty) {
        for (var charge in extraCharges) {
          if (charge is Map) {
            final double cWeight = ((charge['weight'] ?? 0.0) as num).toDouble();
            final double cRate = ((charge['rate'] ?? charge['salRate'] ?? 0.0) as num).toDouble();
            final double cMetalAmt = (charge['amount'] as num?)?.toDouble() ?? (cWeight > 0 ? cWeight * cRate : (charge['pcs'] ?? 1) * cRate);
            final double cLabourPer = ((charge['labourRate'] ?? charge['salLabRate'] ?? 0.0) as num).toDouble();
            final String cLabourOn = charge['labourOn']?.toString() ?? 'Per Piece';
            final double cLabourAmt = ((charge['labourAmt'] ?? 0.0) as num).toDouble();
            final double cTotal = cMetalAmt + cLabourAmt;

            tableData.add([
              '↳ ${charge['styleName'] ?? ''}',
              '',
              '',
              (charge['pcs'] ?? 1).toString(),
              cWeight > 0 ? '${formatWt(cWeight)}g' : '',
              '',
              'Rs. ${formatAmt(cRate)}',
              'Rs. ${formatAmt(cMetalAmt)}',
              'Rs. ${formatAmt(cLabourPer)} ($cLabourOn)',
              'Rs. ${formatAmt(cLabourAmt)}',
              'Rs. ${formatAmt(cTotal)}',
            ]);
          }
        }
      }
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: tableData,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 6.5, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.brown900),
      cellStyle: const pw.TextStyle(fontSize: 6.5),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight,
        7: pw.Alignment.centerRight,
        8: pw.Alignment.centerLeft,
        9: pw.Alignment.centerRight,
        10: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildPdfFinancialSummary(Map<String, dynamic> docData, String Function(dynamic) formatAmt) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildSummaryText('Base Metal Amount:', 'Rs. ${formatAmt(docData['metalAmt'])}'),
                _buildSummaryText('Total Labour Amount:', 'Rs. ${formatAmt(docData['labourAmt'])}'),
                _buildSummaryText('Other Charges:', 'Rs. ${formatAmt(docData['othCharge'])}'),
                _buildSummaryText('Discount Amount:', '- Rs. ${formatAmt(docData['discountAmt'])}'),
                pw.SizedBox(height: 4),
                _buildSummaryText('CGST Amount:', 'Rs. ${formatAmt(docData['cgstAmt'])}'),
                _buildSummaryText('SGST Amount:', 'Rs. ${formatAmt(docData['sgstAmt'])}'),
                _buildSummaryText('IGST Amount:', 'Rs. ${formatAmt(docData['igstAmt'])}'),
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildSummaryText('Subtotal (After Disc):', 'Rs. ${formatAmt(docData['afterDiscount'])}', isBold: true),
                _buildSummaryText('GST Total (Tax):', 'Rs. ${formatAmt(docData['gstAmt'])}'),
                _buildSummaryText('Round Off / Rnd Disc:', '- Rs. ${formatAmt(docData['rndDiscount'])}'),
                pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 3), height: 0.5, color: PdfColors.grey400),
                _buildSummaryText('Total Voucher Amt:', 'Rs. ${formatAmt(docData['voucherAmt'])}', isBold: true, color: PdfColors.brown900, fontSize: 9),
                _buildSummaryText('Total Amount Paid:', 'Rs. ${formatAmt(docData['paymentAmt'])}', isBold: true, color: PdfColors.green800, fontSize: 8),
                _buildSummaryText('Balance Due Amt:', 'Rs. ${formatAmt(docData['dueAmt'])}', isBold: true, color: PdfColors.red800, fontSize: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryText(String label, String value, {bool isBold = false, double fontSize = 7.5, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.SizedBox(width: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: fontSize, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color ?? PdfColors.black)),
        ],
      ),
    );
  }
}
