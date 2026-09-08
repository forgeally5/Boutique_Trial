import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

String numberToWords(double amount) {
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

class CashVoucherPrintDialog extends StatelessWidget {
  final String voucherNo;
  final String date;
  final String accountName;
  final String address;
  final String phone;
  final String panNo;
  final double amount;
  final String narration;
  final String voucherType;
  final String placeOfSupply;
  final bool isBank;
  final String chequeRefNo;
  final String chequeDate;
  final String billNo;
  final String billDate;
  final String gstNo;
  final double cgst;
  final double sgst;
  final double igst;
  final double taxableAmount;
  final bool gstApplicable;

  const CashVoucherPrintDialog({
    super.key,
    required this.voucherNo,
    required this.date,
    required this.accountName,
    this.address = '',
    this.phone = '',
    this.panNo = '',
    required this.amount,
    this.narration = '',
    this.voucherType = 'Cash Payment',
    this.placeOfSupply = 'Gujarat',
    this.isBank = false,
    this.chequeRefNo = '1',
    this.chequeDate = '',
    this.billNo = '',
    this.billDate = '',
    this.gstNo = '',
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    this.taxableAmount = 0.0,
    this.gstApplicable = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String voucherNo,
    required String date,
    required String accountName,
    String address = '',
    String phone = '',
    String panNo = '',
    required double amount,
    String narration = '',
    String voucherType = 'Cash Payment',
    String placeOfSupply = 'Gujarat',
    bool isBank = false,
    String chequeRefNo = '1',
    String chequeDate = '',
    String billNo = '',
    String billDate = '',
    String gstNo = '',
    double cgst = 0.0,
    double sgst = 0.0,
    double igst = 0.0,
    double taxableAmount = 0.0,
    bool gstApplicable = false,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CashVoucherPrintDialog(
        voucherNo: voucherNo,
        date: date,
        accountName: accountName,
        address: address,
        phone: phone,
        panNo: panNo,
        amount: amount,
        narration: narration,
        voucherType: voucherType,
        placeOfSupply: placeOfSupply,
        isBank: isBank,
        chequeRefNo: chequeRefNo,
        chequeDate: chequeDate,
        billNo: billNo,
        billDate: billDate,
        gstNo: gstNo,
        cgst: cgst,
        sgst: sgst,
        igst: igst,
        taxableAmount: taxableAmount,
        gstApplicable: gstApplicable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountInWords = numberToWords(amount);
    final formattedAmount = NumberFormat('#,##,##0.00').format(amount);
    final bool isReceipt = voucherType.toLowerCase().contains('receipt') ||
        voucherType.toLowerCase() == 'inward service';
    final String formattedChequeDate = chequeDate.isNotEmpty ? chequeDate : date;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 780,
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
                  Row(
                    children: [
                      const Icon(Icons.print_outlined, color: _brown, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isBank ? 'Bank Voucher Print Preview' : 'Cash Voucher Print Preview',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown),
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
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                  children: [
                    // Header Section
                    const Text(
                      'TRILOK',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _brown, letterSpacing: 2),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'by OM SRI JEWEL',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLight, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 16),

                    // Main Outer Receipt Border Box
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black87, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Top Row (Customer Info Left | Voucher Info Right)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left Customer Box
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black87, width: 1),
                                        bottom: BorderSide(color: Colors.black87, width: 1),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Shri/Smt. : ${accountName.isNotEmpty ? accountName : (isBank ? 'KAMLESHJI' : 'ELECTRICITY BILL')}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black)),
                                        const SizedBox(height: 6),
                                        Text('Address   : $address', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                        const SizedBox(height: 12),
                                        Text('Phone     : $phone', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                      ],
                                    ),
                                  ),
                                ),
                                // Right Voucher Info Box
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                                    ),
                                    child: Column(
                                      children: [
                                        // Header Badge
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.black54),
                                            color: const Color(0xFFF9F9F9),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            voucherType,
                                            style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, fontFamily: 'serif', color: Colors.black),
                                          ),
                                        ),
                                        // Details
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Text('Voucher No :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 4),
                                                  Text(voucherNo.isNotEmpty ? voucherNo : (isBank ? 'B / 1' : 'C / 1'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Text('Date.           :', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 4),
                                                  Text(date.isNotEmpty ? date : DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        gstNo.isNotEmpty ? 'GST No.       :' : 'PAN No.       :',
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        gstNo.isNotEmpty ? gstNo : panNo,
                                                        style: const TextStyle(fontSize: 11),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Middle Section Box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 12, color: Colors.black, height: 1.5),
                                    children: [
                                      TextSpan(
                                        text: isReceipt ? 'Received Rs. ' : 'Paid Rs. ',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      TextSpan(text: '$amountInWords ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      if (isBank)
                                        TextSpan(text: 'By Cheque/Draft No ${chequeRefNo.isNotEmpty ? chequeRefNo : '1'} Dt. $formattedChequeDate ')
                                      else
                                        const TextSpan(text: ''),
                                      const TextSpan(text: 'For'),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (narration.isNotEmpty)
                                  Text(
                                    narration,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                  )
                                else if (accountName.isNotEmpty)
                                  Text(
                                    accountName,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                const SizedBox(height: 12),
                                Text(
                                  'in Full/Part/Advance Payment of our Bill No.: ${billNo.isNotEmpty ? billNo : '_________________'} Dated : ${billDate.isNotEmpty ? billDate : '_________________'}',
                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                ),
                                if (gstApplicable && (cgst > 0 || sgst > 0 || igst > 0)) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9F9F9),
                                      border: Border.all(color: Colors.black38),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Base Amount: Rs. ${taxableAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                            if (cgst > 0) Text('CGST (9.00%): Rs. ${cgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                            if (sgst > 0) Text('SGST (9.00%): Rs. ${sgst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                            if (igst > 0) Text('IGST (18.00%): Rs. ${igst.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                          ],
                                        ),
                                        const Text(
                                          'with GST',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 24),

                                // Total Paid / Received Box at Bottom Right
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEBEBEB),
                                        border: Border.all(color: Colors.black87, width: 1.5),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2, offset: const Offset(1, 2)),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isReceipt ? 'Total Received : ' : 'Total Paid : ',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                          const SizedBox(width: 40),
                                          Text(
                                            formattedAmount,
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Bottom Footer Box (Signatures)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Column(
                              children: [
                                const SizedBox(height: 40),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Column(
                                      children: [
                                        Container(width: 150, height: 1, color: Colors.black87),
                                        const SizedBox(height: 4),
                                        const Text('Customer\'s Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const Text('Subject To Jurisdiction Only E. & O.E.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    Column(
                                      children: [
                                        Container(width: 150, height: 1, color: Colors.black87),
                                        const SizedBox(height: 4),
                                        const Text('Authorised Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
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

            // Bottom Actions Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: _headerBg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 16, color: _brown),
                    label: const Text('Close', style: TextStyle(color: _brown)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: _border)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Printing receipt...'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Receipt'),
                    style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
