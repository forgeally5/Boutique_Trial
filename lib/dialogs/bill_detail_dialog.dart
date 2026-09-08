import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:trial/utils/pdf_bill_detail_generator.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

class BillDetailDialog extends StatelessWidget {
  final Map<String, dynamic> docData;

  const BillDetailDialog({super.key, required this.docData});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final voucherNo = docData['voucherNo']?.toString() ?? '';
    final billType = docData['billType']?.toString() ?? 'Sale';
    final rawDate = docData['voucherDate'];
    final dateStr = rawDate is Timestamp
        ? DateFormat('dd/MM/yyyy EEE').format(rawDate.toDate())
        : rawDate?.toString() ?? '';

    final acName = docData['acName']?.toString() ?? '';
    final salesman = docData['salesman']?.toString() ?? '';
    final placeOfSupply = docData['placeOfSupply']?.toString() ?? '';
    final dueDate = docData['dueDate']?.toString() ?? '';
    final customerDetails = docData['customerDetails'] as Map?;
    final gstin = customerDetails?['gstin']?.toString() ??
        docData['gstinNo']?.toString() ??
        docData['gstin']?.toString() ??
        '';

    final items = docData['items'] as List? ?? [];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: size.width * 0.9,
        height: size.height * 0.9,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            // ── Dialog Header ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bill Details: $voucherNo ($billType)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.print, color: Colors.white),
                        tooltip: 'Print PDF',
                        onPressed: () => _handlePrintAndDownload(context, voucherNo, acName, billType == 'Purchase'),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Dialog Body (Scrollable) ────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header Information Grid
                    _buildSectionHeader('General Info'),
                    const SizedBox(height: 8),
                    _buildInfoGrid([
                      _buildInfoTileWithButton(
                        context,
                        billType == 'Sale' ? 'Account / Customer' : 'Account / Supplier',
                        acName,
                        buttonLabel: billType == 'Sale' ? 'Customer Details' : 'Supplier Details',
                        onPressed: () => _showPartyDetails(context, acName, billType == 'Purchase'),
                      ),
                      _buildInfoTile('Voucher No', voucherNo),
                      _buildInfoTile('Voucher Date', dateStr),
                      _buildInfoTile('GSTIN / Tax ID', gstin.isNotEmpty ? gstin : 'N/A'),
                      _buildInfoTile('Salesman', salesman.isNotEmpty ? salesman : 'N/A'),
                      _buildInfoTile('Place of Supply', placeOfSupply.isNotEmpty ? placeOfSupply : 'N/A'),
                      _buildInfoTile('Due Date', dueDate.isNotEmpty ? dueDate : 'N/A'),
                      _buildInfoTile('Purity / Carat', docData['carat']?.toString() ?? 'N/A'),
                    ]),
                    const SizedBox(height: 24),

                    // 2. Items List Table
                    _buildSectionHeader('Items Breakdown'),
                    const SizedBox(height: 8),
                    items.isEmpty
                        ? _buildLegacyItemPlaceholder()
                        : _buildItemsTable(items),
                    const SizedBox(height: 24),

                    // 3. Payment & Bottom Panel Details
                    _buildSectionHeader('Payment & Bottom Panel Details'),
                    const SizedBox(height: 8),
                    _buildInfoGrid([
                      _buildInfoTile('Cash Amount Paid', '₹ ${_formatAmt(docData['cashAmt'])}'),
                      _buildInfoTile(
                        'Bank Amount Paid',
                        '₹ ${_formatAmt(docData['bankAmt'])}${docData['bankName'] != null && docData['bankName'].toString().isNotEmpty ? ' (${docData['bankName']})' : ''}',
                      ),
                      _buildInfoTile(
                        'Card Amount Paid',
                        '₹ ${_formatAmt(docData['cardAmt'])}${docData['cardMachine'] != null && docData['cardMachine'].toString().isNotEmpty ? ' (${docData['cardMachine']})' : ''}',
                      ),
                      _buildInfoTile('Old Gold Purchase Amt', '₹ ${_formatAmt(docData['ogPurchaseAmt'])}'),
                      _buildInfoTile('Sales Return Amt', '₹ ${_formatAmt(docData['salesReturnAmt'])}'),
                      _buildInfoTile('Gold Scheme Amt', '₹ ${_formatAmt(docData['goldSchemeAmt'])}'),
                      _buildInfoTile('Rate Apply Amt', '₹ ${_formatAmt(docData['rateApplyAmt'])}'),
                      _buildInfoTile('Metal Settled Weight', '${_formatWt(docData['metalSettledWt'])}g'),
                      _buildInfoTile('Rate Difference Amt', '₹ ${_formatAmt(docData['rateDiffAmt'])}'),
                      _buildInfoTile('AP Amount', '₹ ${_formatAmt(docData['apAmt'])}'),
                    ]),
                    const SizedBox(height: 12),

                    // Extended Bank & Card Info
                    if (_hasExtendedDetails()) ...[
                      const SizedBox(height: 8),
                      _buildInfoGrid([
                        if (docData['bankChequeNo']?.toString().isNotEmpty ?? false)
                          _buildInfoTile('Bank Cheque/Ref No.', docData['bankChequeNo'].toString()),
                        if (docData['bankRemarks']?.toString().isNotEmpty ?? false)
                          _buildInfoTile('Bank Remarks', docData['bankRemarks'].toString()),
                        if (docData['cardApprovalNo']?.toString().isNotEmpty ?? false)
                          _buildInfoTile('Card Approval/Ref No.', docData['cardApprovalNo'].toString()),
                        if (docData['cardRemarks']?.toString().isNotEmpty ?? false)
                          _buildInfoTile('Card Remarks', docData['cardRemarks'].toString()),
                      ]),
                    ],

                    // Old Gold metadata panel details
                    if (docData['ogGrossWt'] != null && (docData['ogGrossWt'] as num) > 0) ...[
                      const SizedBox(height: 16),
                      _buildSectionHeader('Old Gold Metadata'),
                      const SizedBox(height: 8),
                      _buildInfoGrid([
                        _buildInfoTile('OG Gross Weight', '${_formatWt(docData['ogGrossWt'])}g'),
                        _buildInfoTile('OG Dust Weight', '${_formatWt(docData['ogDustWt'])}g'),
                        _buildInfoTile('OG Net Weight', '${_formatWt(docData['ogNetWt'])}g'),
                        _buildInfoTile('OG Wastage %', '${_formatWt(docData['ogWastage'])}%'),
                        _buildInfoTile('OG Final Weight', '${_formatWt(docData['ogFinalWt'])}g'),
                        _buildInfoTile('OG Rate Applied', '₹ ${_formatAmt(docData['ogRate'])}'),
                      ]),
                    ],

                    if (docData['narration']?.toString().isNotEmpty ?? false) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('Narration'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: _border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          docData['narration'].toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 4. Financial Totals Card
                    _buildSectionHeader('Financial Summary'),
                    const SizedBox(height: 8),
                    _buildFinancialSummaryCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPartyDetails(BuildContext context, String name, bool isSupplier) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _PartyDetailsFetchDialog(name: name, isSupplier: isSupplier);
      },
    );
  }

  void _handlePrintAndDownload(BuildContext context, String voucherNo, String acName, bool isSupplier) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: _brown),
            SizedBox(width: 20),
            Text('Generating PDF and loading profiles...'),
          ],
        ),
      ),
    );

    Map<String, dynamic>? profileData;
    try {
      final collection = isSupplier ? 'suppliers' : 'customers';
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('name', isEqualTo: acName)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        profileData = snap.docs.first.data();
        profileData['id'] = snap.docs.first.id;
      }
    } catch (e) {
      debugPrint('Error fetching profile for PDF: $e');
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Close loading dialog

    try {
      final pdfBytes = await PdfBillDetailGenerator.generate(docData, profileData, isSupplier);

      // Download file to Downloads folder
      final rawFileName = '${voucherNo}_$acName.pdf';
      final fileName = rawFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final base64Str = base64Encode(pdfBytes);
      if (!context.mounted) return;
      await _downloadFile(context, fileName, base64Str);

      // Open print layout preview
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: fileName.replaceAll('.pdf', ''),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _hasExtendedDetails() {
    return (docData['bankChequeNo']?.toString().isNotEmpty ?? false) ||
        (docData['bankRemarks']?.toString().isNotEmpty ?? false) ||
        (docData['cardApprovalNo']?.toString().isNotEmpty ?? false) ||
        (docData['cardRemarks']?.toString().isNotEmpty ?? false);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: _brown,
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: children.map((c) => SizedBox(width: 260, child: c)).toList(),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: _brownLight, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTileWithButton(
    BuildContext context,
    String label,
    String value, {
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: _brownLight, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: onPressed,
            child: Text(buttonLabel),
          )
        ],
      ),
    );
  }

  Widget _buildLegacyItemPlaceholder() {
    final name = docData['itemName']?.toString() ?? 'N/A';
    final gross = docData['grossWeight'] ?? docData['grossWt'] ?? 0.0;
    final net = docData['netWeight'] ?? docData['netWt'] ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Itemized details not available for this legacy record. Summary:',
            style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Item Name: $name', style: const TextStyle(fontSize: 12)),
          Text('Gross Weight: ${_formatWt(gross)}g', style: const TextStyle(fontSize: 12)),
          Text('Net Weight: ${_formatWt(net)}g', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildItemsTable(List itemsList) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2), // Tag
          1: FlexColumnWidth(3), // Item Name
          2: FlexColumnWidth(1.5), // Carat
          3: FlexColumnWidth(1.2), // Pcs
          4: FlexColumnWidth(2), // Gross Wt
          5: FlexColumnWidth(2), // Net Wt
          6: FlexColumnWidth(2), // Rate
          7: FlexColumnWidth(2), // Metal Amt
          8: FlexColumnWidth(3.5), // Labour details
          9: FlexColumnWidth(2), // Labour Amt
          10: FlexColumnWidth(2), // Row Total
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: _headerBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            children: [
              _buildTableHeaderCell('Tag No'),
              _buildTableHeaderCell('Item Name'),
              _buildTableHeaderCell('Carat'),
              _buildTableHeaderCell('Pcs'),
              _buildTableHeaderCell('Gross Wt'),
              _buildTableHeaderCell('Net Wt'),
              _buildTableHeaderCell('Rate'),
              _buildTableHeaderCell('Metal Amt'),
              _buildTableHeaderCell('Labour Formula'),
              _buildTableHeaderCell('Labour Amt'),
              _buildTableHeaderCell('Total'),
            ],
          ),
          ...itemsList.map((item) {
            final double metalAmt = (item['totMetalAmt'] as num?)?.toDouble() ??
                (item['metalAmt'] as num?)?.toDouble() ?? 0.0;
            final double labourAmt = (item['labourAmt'] as num?)?.toDouble() ?? 0.0;
            final double rowTotal = metalAmt + labourAmt;

            final labourOn = item['labourOn']?.toString() ?? 'Per Piece';
            final double labourRate = (item['labourRate'] as num?)?.toDouble() ?? 0.0;

            String labFormula = '';
            if (labourOn.contains('Net Wt')) {
              labFormula = '₹${labourRate.toStringAsFixed(2)} /g Net';
            } else if (labourOn.contains('Gross Wt')) {
              labFormula = '₹${labourRate.toStringAsFixed(2)} /g Gross';
            } else if (labourOn.contains('Percentage')) {
              labFormula = '${labourRate.toStringAsFixed(2)}%';
            } else {
              labFormula = '₹${labourRate.toStringAsFixed(2)} /pc';
            }

            return TableRow(
              children: [
                _buildTableCell(item['tagId']?.toString() ?? 'N/A'),
                _buildTableCell(item['name']?.toString() ?? ''),
                _buildTableCell(item['purity']?.toString() ?? ''),
                _buildTableCell(item['pcs']?.toString() ?? '1'),
                _buildTableCell('${_formatWt(item['grossWeight'])}g'),
                _buildTableCell('${_formatWt(item['netWeight'])}g'),
                _buildTableCell('₹${_formatAmt(item['rate'])}'),
                _buildTableCell('₹${_formatAmt(metalAmt)}'),
                _buildTableCell('$labFormula\n($labourOn)', fontSize: 9),
                _buildTableCell('₹${_formatAmt(labourAmt)}'),
                _buildTableCell('₹${_formatAmt(rowTotal)}', isBold: true),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brown),
      ),
    );
  }

  Widget _buildTableCell(String text, {double fontSize = 10, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildFinancialSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow('Base Metal Amount:', '₹ ${_formatAmt(docData['metalAmt'])}'),
              _buildSummaryRow('Total Labour Amount:', '₹ ${_formatAmt(docData['labourAmt'])}'),
              _buildSummaryRow('Other Charges:', '₹ ${_formatAmt(docData['othCharge'])}'),
              _buildSummaryRow('Discount Amount:', '- ₹ ${_formatAmt(docData['discountAmt'])}'),
              const SizedBox(height: 8),
              _buildSummaryRow('CGST Amount:', '₹ ${_formatAmt(docData['cgstAmt'])}'),
              _buildSummaryRow('SGST Amount:', '₹ ${_formatAmt(docData['sgstAmt'])}'),
              _buildSummaryRow('IGST Amount:', '₹ ${_formatAmt(docData['igstAmt'])}'),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSummaryRow('Subtotal (After Disc):', '₹ ${_formatAmt(docData['afterDiscount'])}', isBold: true),
              _buildSummaryRow('GST Total (Tax):', '₹ ${_formatAmt(docData['gstAmt'])}'),
              _buildSummaryRow('Round Off / Rnd Disc:', '- ₹ ${_formatAmt(docData['rndDiscount'])}'),
              const Divider(height: 16, thickness: 1),
              _buildSummaryRow('Total Voucher Amt:', '₹ ${_formatAmt(docData['voucherAmt'])}', isBold: true, fontSize: 16, color: _brown),
              _buildSummaryRow('Total Amount Paid:', '₹ ${_formatAmt(docData['paymentAmt'])}', isBold: true, fontSize: 14, color: Colors.green.shade800),
              _buildSummaryRow('Balance Due Amt:', '₹ ${_formatAmt(docData['dueAmt'])}', isBold: true, fontSize: 14, color: Colors.red.shade800),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 12, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black54,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmt(dynamic val) {
    if (val == null) return '0.00';
    final d = (val as num?)?.toDouble() ?? 0.0;
    return d.toStringAsFixed(2);
  }

  String _formatWt(dynamic val) {
    if (val == null) return '0.000';
    final d = (val as num?)?.toDouble() ?? 0.0;
    return d.toStringAsFixed(3);
  }
}

class _PartyDetailsFetchDialog extends StatefulWidget {
  final String name;
  final bool isSupplier;

  const _PartyDetailsFetchDialog({required this.name, required this.isSupplier});

  @override
  State<_PartyDetailsFetchDialog> createState() => _PartyDetailsFetchDialogState();
}

class _PartyDetailsFetchDialogState extends State<_PartyDetailsFetchDialog> {
  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final collection = widget.isSupplier ? 'suppliers' : 'customers';
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('name', isEqualTo: widget.name)
          .limit(1)
          .get();

      if (!mounted) return;
      Navigator.pop(context); // Close loader

      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        data['id'] = snap.docs.first.id;
        showDialog(
          context: context,
          builder: (context) => PartyProfileViewerDialog(
            profileData: data,
            isSupplier: widget.isSupplier,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ No registered profile found for "${widget.name}"'),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error fetching profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(color: _brown),
          SizedBox(width: 20),
          Text('Fetching profile details...'),
        ],
      ),
    );
  }
}

class PartyProfileViewerDialog extends StatelessWidget {
  final Map<String, dynamic> profileData;
  final bool isSupplier;

  const PartyProfileViewerDialog({super.key, required this.profileData, required this.isSupplier});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final name = profileData['name']?.toString() ?? 'N/A';
    final code = isSupplier
        ? (profileData['supplierCode'] ?? 'N/A')
        : (profileData['customerCode'] ?? 'N/A');

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: size.width * 0.75,
        height: size.height * 0.8,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${isSupplier ? "Supplier" : "Customer"} Profile: $name ($code)',
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Photo, Address, Mobile
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfilePhoto(),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Contact Details'),
                          const SizedBox(height: 8),
                          _buildField('Primary Mobile', profileData['mobileNo1']),
                          _buildField('Secondary Mobile', profileData['mobileNo2']),
                          _buildField('Phone 1', profileData['phoneNo1']),
                          _buildField('Email', profileData['email1']),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Address'),
                          const SizedBox(height: 8),
                          _buildAddressBlock(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right Column: Credit, MSME, Documents Uploaded
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('Tax & Registration Details'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 10,
                            children: [
                              _buildChipField('GSTIN', profileData['gstin']),
                              _buildChipField('PAN No', profileData['pan']),
                              _buildChipField('MSME No', profileData['msmeNo']),
                              _buildChipField('MSME Type', profileData['msmeType']),
                              _buildChipField('Composition Scheme', profileData['isCompositionScheme'] == true ? 'Yes' : 'No'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildSectionTitle('Credit settings'),
                          const SizedBox(height: 8),
                          _buildField('Credit Limit', '₹ ${_formatAmt(profileData['creditLimit'])}'),
                          _buildField('Credit Days', '${profileData['creditDays'] ?? 0} Days'),
                          const SizedBox(height: 24),
                          _buildSectionTitle('Uploaded Documents & Pics'),
                          const SizedBox(height: 12),
                          _buildDocumentsGrid(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePhoto() {
    final photoBase64 = profileData['photoBase64']?.toString() ?? '';
    Uint8List? bytes;
    if (photoBase64.isNotEmpty) {
      try {
        bytes = base64Decode(photoBase64);
      } catch (_) {}
    }

    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: bytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.memory(bytes, width: 140, height: 140, fit: BoxFit.cover),
              )
            : const Icon(Icons.person, size: 70, color: Colors.grey),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown, letterSpacing: 0.5),
    );
  }

  Widget _buildField(String label, dynamic val) {
    final text = val?.toString() ?? '';
    if (text.isEmpty || text == 'null' || text == '0') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLight)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildChipField(String label, dynamic val) {
    final text = val?.toString() ?? '';
    if (text.isEmpty || text == 'null' || text == 'None') return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _brownLight)),
          Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildAddressBlock() {
    final block = profileData['blockNo']?.toString() ?? '';
    final building = profileData['buildingName']?.toString() ?? '';
    final street = profileData['street']?.toString() ?? '';
    final area = profileData['area']?.toString() ?? '';
    final city = profileData['city']?.toString() ?? '';
    final zip = profileData['zipCode']?.toString() ?? '';
    final state = profileData['state']?.toString() ?? '';
    final country = profileData['country']?.toString() ?? '';

    final lines = [
      [block, building].where((s) => s.isNotEmpty).join(', '),
      street,
      area,
      [city, zip].where((s) => s.isNotEmpty).join(' - '),
      [state, country].where((s) => s.isNotEmpty).join(', '),
    ].where((s) => s.isNotEmpty).toList();

    if (lines.isEmpty) {
      return const Text('No address listed.', style: TextStyle(fontSize: 11, color: Colors.grey));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines.map((l) => Text(l, style: const TextStyle(fontSize: 11, color: Colors.black87, height: 1.3))).toList(),
      ),
    );
  }

  Widget _buildDocumentsGrid(BuildContext context) {
    final docs = [
      {'name': 'Photograph', 'key': 'photoBase64', 'file': 'photograph.jpg'},
      {'name': 'Pan Card', 'key': 'panCardBase64', 'file': 'pan_card.jpg'},
      {'name': 'Aadhaar Card', 'key': 'aadhaarBase64', 'file': 'aadhaar_card.jpg'},
      {'name': 'Driving Licence', 'key': 'drivingLicenceBase64', 'file': 'driving_licence.jpg'},
      {'name': 'Election Card', 'key': 'electionCardBase64', 'file': 'election_card.jpg'},
      {'name': 'Passport', 'key': 'passportBase64', 'file': 'passport.jpg'},
    ];

    final uploadedDocs = docs.where((d) => (profileData[d['key']]?.toString().isNotEmpty ?? false)).toList();

    if (uploadedDocs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No documents or pictures uploaded for this profile.',
          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: uploadedDocs.map((doc) {
        final label = doc['name']!;
        final base64Str = profileData[doc['key']]!.toString();
        final fileName = '${profileData['name']}_${doc['file']}';

        Uint8List? thumbBytes;
        try {
          thumbBytes = base64Decode(base64Str);
        } catch (_) {}

        return Container(
          width: 140,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 128,
                height: 90,
                decoration: BoxDecoration(
                  color: _headerBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _border.withAlpha(128)),
                ),
                alignment: Alignment.center,
                child: thumbBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Image.memory(thumbBytes, width: 128, height: 90, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.description, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brown),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 24),
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.download, size: 10),
                label: const Text('Download'),
                onPressed: () => _downloadFile(context, fileName, base64Str),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatAmt(dynamic val) {
    if (val == null) return '0.00';
    final d = (val as num?)?.toDouble() ?? 0.0;
    return d.toStringAsFixed(2);
  }
}

Future<void> _downloadFile(BuildContext context, String fileName, String base64Str) async {
  try {
    if (base64Str.isEmpty) return;
    final bytes = base64Decode(base64Str);

    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    final downloadsPath = '$userProfile\\Downloads';
    final downloadsDir = Directory(downloadsPath);
    if (!downloadsDir.existsSync()) {
      downloadsDir.createSync();
    }

    final file = File('$downloadsPath\\$fileName');
    await file.writeAsBytes(bytes);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('📥 File saved to Downloads: $fileName')),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ Error downloading: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

