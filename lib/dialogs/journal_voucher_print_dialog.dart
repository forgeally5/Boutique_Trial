import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);

String _numberToWords(double amount) {
  final int value = amount.floor();
  if (value == 0) return 'Zero Only';

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

class JournalVoucherPrintDialog extends StatelessWidget {
  final String voucherNo;
  final String date;
  final String voucherType;
  final String bookName;
  final String reference;
  final String placeOfSupply;
  final List<Map<String, dynamic>> rows;
  final double totalDr;
  final double totalCr;
  final double totalDrWt;
  final double totalCrWt;
  final String masterNarration;

  const JournalVoucherPrintDialog({
    super.key,
    required this.voucherNo,
    required this.date,
    required this.voucherType,
    required this.bookName,
    this.reference = '',
    this.placeOfSupply = '',
    required this.rows,
    required this.totalDr,
    required this.totalCr,
    this.totalDrWt = 0.0,
    this.totalCrWt = 0.0,
    this.masterNarration = '',
  });

  static Future<void> show(
    BuildContext context, {
    required String voucherNo,
    required String date,
    required String voucherType,
    required String bookName,
    String reference = '',
    String placeOfSupply = '',
    required List<Map<String, dynamic>> rows,
    required double totalDr,
    required double totalCr,
    double totalDrWt = 0.0,
    double totalCrWt = 0.0,
    String masterNarration = '',
  }) {
    return showDialog(
      context: context,
      builder: (_) => JournalVoucherPrintDialog(
        voucherNo: voucherNo,
        date: date,
        voucherType: voucherType,
        bookName: bookName,
        reference: reference,
        placeOfSupply: placeOfSupply,
        rows: rows,
        totalDr: totalDr,
        totalCr: totalCr,
        totalDrWt: totalDrWt,
        totalCrWt: totalCrWt,
        masterNarration: masterNarration,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountInWords = _numberToWords(totalDr > 0 ? totalDr : totalCr);

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Title Bar
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
                        'Journal Voucher Print Preview',
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

            // Printable Content Area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(20),
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
                      // Header Section
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              'TRILOK',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _brown, letterSpacing: 2),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'by OM SRI JEWEL',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brownLight, letterSpacing: 0.5),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'JOURNAL VOUCHER',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Voucher Header Metadata Box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black87),
                          color: const Color(0xFFFAFAFA),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: Colors.black),
                                      children: [
                                        const TextSpan(text: 'Voucher No  : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: voucherNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: Colors.black),
                                      children: [
                                        const TextSpan(text: 'Voucher Date : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: date),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: Colors.black),
                                      children: [
                                        const TextSpan(text: 'Book Name   : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: bookName),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(fontSize: 12, color: Colors.black),
                                      children: [
                                        const TextSpan(text: 'Voucher Type : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                        TextSpan(text: voucherType),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (reference.isNotEmpty || placeOfSupply.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (reference.isNotEmpty)
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 12, color: Colors.black),
                                          children: [
                                            const TextSpan(text: 'Reference    : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                            TextSpan(text: reference),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (placeOfSupply.isNotEmpty)
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(fontSize: 12, color: Colors.black),
                                          children: [
                                            const TextSpan(text: 'Place of Supply: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                            TextSpan(text: placeOfSupply),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Journal Entries Table
                      Table(
                        columnWidths: const {
                          0: FixedColumnWidth(40), // Sl
                          1: FixedColumnWidth(55), // Dr/Cr
                          2: FlexColumnWidth(2.5), // Account
                          3: FlexColumnWidth(1.8), // Particulars
                          4: FixedColumnWidth(80), // Wt (g)
                          5: FixedColumnWidth(80), // Ref No
                          6: FixedColumnWidth(110), // Amount
                        },
                        border: TableBorder.all(color: Colors.black87, width: 1),
                        children: [
                          // Table Header
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFF0EBE1)),
                            children: [
                              Padding(padding: EdgeInsets.all(6), child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(6), child: Text('Dr/Cr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(6), child: Text('Account Particulars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Trading / Metal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Weight (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                              Padding(padding: EdgeInsets.all(6), child: Text('Ref No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              Padding(padding: EdgeInsets.all(6), child: Text('Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                            ],
                          ),
                          // Rows
                          ...rows.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final r = entry.value;
                            final String crDr = r['crDr']?.toString() ?? 'DR';
                            final String account = r['account']?.toString() ?? r['accountName']?.toString() ?? '';
                            final String trading = r['trading']?.toString() ?? '';
                            final String metal = r['metal']?.toString() ?? '';
                            final double weight = (r['weight'] as double?) ?? double.tryParse(r['weight']?.toString() ?? '') ?? 0.0;
                            final double amount = (r['amount'] as double?) ?? double.tryParse(r['amount']?.toString() ?? '') ?? 0.0;
                            final String refNo = r['refNo']?.toString() ?? '';

                            String details = trading;
                            if (metal.isNotEmpty) {
                              details = details.isNotEmpty ? '$details ($metal)' : metal;
                            }

                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(6), child: Text('$idx', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Text(
                                    crDr,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: crDr == 'DR' ? Colors.blue.shade900 : Colors.green.shade900,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Padding(padding: const EdgeInsets.all(6), child: Text(account, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(details, style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(weight > 0 ? weight.toStringAsFixed(3) : '-', style: const TextStyle(fontSize: 11), textAlign: TextAlign.right)),
                                Padding(padding: const EdgeInsets.all(6), child: Text(refNo, style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text(NumberFormat('#,##,##0.00').format(amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                              ],
                            );
                          }),
                          // Total Row
                          TableRow(
                            decoration: const BoxDecoration(color: Color(0xFFFAFAFA)),
                            children: [
                              const Padding(padding: EdgeInsets.all(6), child: Text('')),
                              const Padding(padding: EdgeInsets.all(6), child: Text('')),
                              const Padding(padding: EdgeInsets.all(6), child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              const Padding(padding: EdgeInsets.all(6), child: Text('')),
                              Padding(padding: const EdgeInsets.all(6), child: Text(totalDrWt > 0 ? totalDrWt.toStringAsFixed(3) : '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.right)),
                              const Padding(padding: EdgeInsets.all(6), child: Text('')),
                              Padding(padding: const EdgeInsets.all(6), child: Text('₹${NumberFormat('#,##,##0.00').format(totalDr)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue), textAlign: TextAlign.right)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Amount in words & Narration section
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black87),
                          color: const Color(0xFFFAFAFA),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Amount in Words : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                  TextSpan(text: amountInWords, style: const TextStyle(fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (masterNarration.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                  children: [
                                    const TextSpan(text: 'Narration        : ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    TextSpan(text: masterNarration),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Signatures Footer
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prepared By: ______________', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Checked By: ______________', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Authorized Signatory', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Dialog Footer Action Buttons (Image 1 style: Print, Close)
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
                      const SnackBar(content: Text('Sending Journal Voucher to printer...')),
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
