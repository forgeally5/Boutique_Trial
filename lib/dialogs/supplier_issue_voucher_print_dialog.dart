import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);

String _numberToWords(double amount) {
  final int value = amount.floor();
  if (value == 0) return '';

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

class SupplierIssueVoucherPrintDialog extends StatelessWidget {
  final String companyName;
  final String location;
  final String voucherTitle;
  final String name;
  final String address;
  final String voucherNo;
  final String date;
  final String copyType;
  final List<Map<String, dynamic>> items;
  final String narration;
  final double byCash;
  final double byCheque;
  final double byCard;
  final double totalAmount;
  final double receiptAmt;
  final double netAmount;
  final double previousAmt;
  final double balance;

  const SupplierIssueVoucherPrintDialog({
    super.key,
    this.companyName = 'ORNJEW1920',
    this.location = 'Gujarat',
    this.voucherTitle = 'SUPPLIER ISSUE VOUCHER',
    required this.name,
    this.address = 'AHMEDABAD,Gujarat',
    required this.voucherNo,
    required this.date,
    this.copyType = 'ORIGINAL',
    required this.items,
    this.narration = '',
    this.byCash = 0.0,
    this.byCheque = 0.0,
    this.byCard = 0.0,
    this.totalAmount = 0.0,
    this.receiptAmt = 0.0,
    this.netAmount = 0.0,
    this.previousAmt = 0.0,
    this.balance = 0.0,
  });

  static Future<void> show(
    BuildContext context, {
    String companyName = 'ORNJEW1920',
    String location = 'Gujarat',
    String voucherTitle = 'SUPPLIER ISSUE VOUCHER',
    required String name,
    String address = 'AHMEDABAD,Gujarat',
    required String voucherNo,
    required String date,
    String copyType = 'ORIGINAL',
    required List<Map<String, dynamic>> items,
    String narration = '',
    double byCash = 0.0,
    double byCheque = 0.0,
    double byCard = 0.0,
    double totalAmount = 0.0,
    double receiptAmt = 0.0,
    double netAmount = 0.0,
    double previousAmt = 0.0,
    double balance = 0.0,
  }) {
    return showDialog(
      context: context,
      builder: (_) => SupplierIssueVoucherPrintDialog(
        companyName: companyName,
        location: location,
        voucherTitle: voucherTitle,
        name: name,
        address: address,
        voucherNo: voucherNo,
        date: date,
        copyType: copyType,
        items: items,
        narration: narration,
        byCash: byCash,
        byCheque: byCheque,
        byCard: byCard,
        totalAmount: totalAmount,
        receiptAmt: receiptAmt,
        netAmount: netAmount,
        previousAmt: previousAmt,
        balance: balance,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total weights and pcs
    int totalPcs = 0;
    double totalGross = 0.0;
    double totalNet = 0.0;

    for (var item in items) {
      totalPcs += (item['pcs'] as int? ?? 1);
      totalGross += (item['grossWt'] as double? ?? 0.0);
      totalNet += (item['netWt'] as double? ?? 0.0);
    }

    final String amountInWords = totalAmount > 0 ? _numberToWords(totalAmount) : '';

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 880,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Window Title Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.print_outlined, color: _brown, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Supplier Issue Voucher Print Preview',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _brownLight),
                  ),
                ],
              ),
            ),

            // Printable Document Area (Matching User Screenshot Exactly)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Company Header Center
                      Center(
                        child: Column(
                          children: [
                            Text(
                              companyName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              location,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. Top Info Box (Name & Address Left | Voucher Info Right)
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black87, width: 1),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Box (Customer / Supplier Info)
                              Expanded(
                                flex: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    border: Border(right: BorderSide(color: Colors.black87, width: 1)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text('Name    :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                          const SizedBox(width: 4),
                                          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Address :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                          const SizedBox(width: 4),
                                          Expanded(child: Text(address, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Right Box (Voucher Title & Metadata)
                              Expanded(
                                flex: 4,
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        voucherTitle,
                                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: Colors.black),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text('Voucher No. : ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                                  Text(voucherNo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                                ],
                                              ),
                                              Text(copyType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Text('Date            : ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                              Text(date, style: const TextStyle(fontSize: 11, color: Colors.black)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Items Table
                      Table(
                        columnWidths: const {
                          0: FixedColumnWidth(32),  // Sr. No.
                          1: FlexColumnWidth(2.2),  // Description
                          2: FixedColumnWidth(36),  // Pcs
                          3: FixedColumnWidth(55),  // Purity
                          4: FixedColumnWidth(70),  // Gross Wt. (Grms)
                          5: FixedColumnWidth(65),  // Other Wt.
                          6: FixedColumnWidth(70),  // Net Wt. (Grms)
                          7: FixedColumnWidth(65),  // Other Charge
                          8: FixedColumnWidth(65),  // Labour Rate
                          9: FixedColumnWidth(75),  // Labour Amount
                        },
                        border: TableBorder.all(color: Colors.black87, width: 1),
                        children: [
                          // Header Row
                          const TableRow(
                            children: [
                              _Th('Sr.\nNo.', align: TextAlign.center),
                              _Th('Description', align: TextAlign.center),
                              _Th('Pcs', align: TextAlign.center),
                              _Th('Purity', align: TextAlign.center),
                              _Th('Gross Wt.\n(Grms)', align: TextAlign.center),
                              _Th('Other Wt.', align: TextAlign.center),
                              _Th('Net Wt.\n(Grms)', align: TextAlign.center),
                              _Th('Other\nCharge', align: TextAlign.center),
                              _Th('Labour\nRate', align: TextAlign.center),
                              _Th('Labour\nAmount', align: TextAlign.center),
                            ],
                          ),

                          // Data Rows
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final r = entry.value;
                            final String desc = r['itemName']?.toString() ?? r['description']?.toString() ?? 'CHAIN';
                            final int pcs = r['pcs'] as int? ?? int.tryParse(r['pcs']?.toString() ?? '') ?? 1;
                            final String purity = r['purity']?.toString() ?? '22 KT';
                            final double gross = (r['grossWt'] as double?) ?? double.tryParse(r['grossWt']?.toString() ?? '') ?? 0.0;
                            final double net = (r['netWt'] as double?) ?? double.tryParse(r['netWt']?.toString() ?? '') ?? gross;
                            final double otherWt = (r['otherWt'] as double?) ?? 0.0;
                            final double otherCharge = (r['otherCharge'] as double?) ?? 0.0;
                            final double labourRate = (r['labourRate'] as double?) ?? 0.0;
                            final double labourAmount = (r['labourAmount'] as double?) ?? 0.0;

                            return TableRow(
                              children: [
                                _Td('$idx', align: TextAlign.center),
                                _Td(desc),
                                _Td('$pcs', align: TextAlign.center),
                                _Td(purity, align: TextAlign.center),
                                _Td(gross > 0 ? gross.toStringAsFixed(3) : '', align: TextAlign.right),
                                _Td(otherWt > 0 ? otherWt.toStringAsFixed(3) : '', align: TextAlign.right),
                                _Td(net > 0 ? net.toStringAsFixed(3) : '', align: TextAlign.right),
                                _Td(otherCharge > 0 ? trailingZeros(otherCharge) : '', align: TextAlign.right),
                                _Td(labourRate > 0 ? trailingZeros(labourRate) : '', align: TextAlign.right),
                                _Td(labourAmount > 0 ? trailingZeros(labourAmount) : '', align: TextAlign.right),
                              ],
                            );
                          }),

                          // Minimum empty height row if items are few
                          if (items.length < 3)
                            TableRow(
                              children: List.generate(
                                10,
                                (_) => const SizedBox(height: 120),
                              ),
                            ),

                          // Total Weight in Grams Row
                          TableRow(
                            children: [
                              const SizedBox(),
                              const _Td('Total Weight in Grams.', isBold: true),
                              _Td('$totalPcs', isBold: true, align: TextAlign.center),
                              const SizedBox(),
                              _Td(totalGross > 0 ? totalGross.toStringAsFixed(3) : '0.000', isBold: true, align: TextAlign.right),
                              const SizedBox(),
                              _Td(totalNet > 0 ? totalNet.toStringAsFixed(3) : '0.000', isBold: true, align: TextAlign.right),
                              const SizedBox(),
                              const SizedBox(),
                              const SizedBox(),
                            ],
                          ),
                        ],
                      ),

                      // 4. Bottom Summary Section (Three Horizontal Boxes)
                      Container(
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.black87, width: 1),
                            right: BorderSide(color: Colors.black87, width: 1),
                            bottom: BorderSide(color: Colors.black87, width: 1),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Top Box: Amount In Words
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                              ),
                              child: Text(
                                'Amount In Words: $amountInWords',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),

                            // Middle Row (Receipts | Narration | Totals Table)
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left Box: Receipts
                                  Expanded(
                                    flex: 35,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        border: Border(right: BorderSide(color: Colors.black87, width: 1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Receipts', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                          const SizedBox(height: 2),
                                          Text('By Cash : ${byCash > 0 ? byCash.toStringAsFixed(2) : ""}', style: const TextStyle(fontSize: 10)),
                                          const SizedBox(height: 2),
                                          Text('By Cheque /D.D. : ${byCheque > 0 ? byCheque.toStringAsFixed(2) : ""}', style: const TextStyle(fontSize: 10)),
                                          const SizedBox(height: 2),
                                          Text('By Card Details : ${byCard > 0 ? byCard.toStringAsFixed(2) : ""}', style: const TextStyle(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Middle Box: Narration
                                  Expanded(
                                    flex: 40,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        border: Border(right: BorderSide(color: Colors.black87, width: 1)),
                                      ),
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 10, color: Colors.black),
                                          children: [
                                            const TextSpan(text: 'Narration ', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                            TextSpan(text: narration.isNotEmpty ? narration : 'REDUCE SIZE BY 1 INCH...'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Right Box: Totals Table
                                  Expanded(
                                    flex: 25,
                                    child: Column(
                                      children: [
                                        _buildSummaryField('Total Amount', totalAmount),
                                        _buildSummaryField('Receipt Amt.', receiptAmt),
                                        _buildSummaryField('Net Amount', netAmount),
                                        _buildSummaryField('Previous Amt.', previousAmt),
                                        _buildSummaryField('Balance', balance, isLast: true),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 35),

                      // 5. Signatures Footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Supplier's Signature",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.overline),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              Text(
                                'Authorised Signature',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black, decoration: TextDecoration.overline),
                              ),
                              SizedBox(height: 4),
                              Text('Page No. 1/1', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Action Buttons (Print & Close)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildFooterCardButton(Icons.print_outlined, 'Print', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sending Supplier Issue Voucher to printer...')),
                    );
                  }),
                  const SizedBox(width: 12),
                  _buildFooterCardButton(Icons.exit_to_app, 'Close', () => Navigator.pop(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryField(String label, double amount, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : Colors.black87, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.black)),
          Text(amount > 0 ? NumberFormat('#,##,##0.00').format(amount) : '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
        ],
      ),
    );
  }

  Widget _buildFooterCardButton(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF7F3EB),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 70,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: _brown),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String trailingZeros(double val) {
  return val.toStringAsFixed(2);
}

class _Th extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _Th(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black, height: 1.1),
      ),
    );
  }
}

class _Td extends StatelessWidget {
  final String text;
  final bool isBold;
  final TextAlign align;
  const _Td(this.text, {this.isBold = false, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: Colors.black,
        ),
      ),
    );
  }
}
