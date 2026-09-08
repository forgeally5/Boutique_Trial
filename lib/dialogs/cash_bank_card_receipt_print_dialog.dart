import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFFCFAF5);
const _headerBg = Color(0xFFF9F6F0);

String numberToWords(double amount) {
  final int value = amount.floor();
  if (value == 0) return 'Zero Rupees Only';

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

  return '${result.trim()} Rupees Only';
}

class CashBankCardReceiptPrintDialog extends StatelessWidget {
  final String recNo;
  final String date;
  final String name;
  final String address;
  final String phone;
  final String itPanNo;
  final String placeOfSupply;
  final List<Map<String, dynamic>> items;
  final double previousOs;

  const CashBankCardReceiptPrintDialog({
    super.key,
    required this.recNo,
    required this.date,
    required this.name,
    this.address = '',
    this.phone = '',
    this.itPanNo = '',
    this.placeOfSupply = 'Gujarat',
    this.items = const [],
    this.previousOs = 300000.00,
  });

  static Future<void> show(
    BuildContext context, {
    required String recNo,
    required String date,
    required String name,
    String address = '',
    String phone = '',
    String itPanNo = '',
    String placeOfSupply = 'Gujarat',
    List<Map<String, dynamic>> items = const [],
    double previousOs = 300000.00,
  }) {
    return showDialog(
      context: context,
      builder: (_) => CashBankCardReceiptPrintDialog(
        recNo: recNo,
        date: date,
        name: name,
        address: address,
        phone: phone,
        itPanNo: itPanNo,
        placeOfSupply: placeOfSupply,
        items: items,
        previousOs: previousOs,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default sample rows if empty
    final List<Map<String, dynamic>> displayRows = items.isNotEmpty
        ? items
        : [
            {
              'particulars': 'Cash',
              'book': 'Cash',
              'refNo': '',
              'date': '',
              'bankName': '',
              'amount': 10000.00,
              'mode': 'Cash',
            },
            {
              'particulars': 'Bank',
              'book': 'ICICI BANK',
              'refNo': '1223',
              'date': '23/10/2019',
              'bankName': 'SBI',
              'amount': 20000.00,
              'mode': 'Bank',
            },
            {
              'particulars': 'Bank / Card',
              'book': 'AXIS BANK',
              'refNo': '123665552',
              'date': '23/10/2019',
              'bankName': 'BOI',
              'amount': 30000.00,
              'mode': 'Card',
            },
          ];

    double cashTotal = 0.0;
    double chequeTotal = 0.0;
    double cardTotal = 0.0;

    for (var r in displayRows) {
      final double amt = (r['amount'] as double?) ?? double.tryParse(r['amount']?.toString() ?? '') ?? 0.0;
      final String mode = r['mode']?.toString() ?? r['particulars']?.toString() ?? '';
      if (mode.contains('Cash')) {
        cashTotal += amt;
      } else if (mode.contains('Card') || mode.contains('Online')) {
        cardTotal += amt;
      } else {
        chequeTotal += amt;
      }
    }

    final double totalReceipt = displayRows.fold(0.0, (acc, r) {
      final double amt = (r['amount'] as double?) ?? double.tryParse(r['amount']?.toString() ?? '') ?? 0.0;
      return acc + amt;
    });

    final String amountInWords = numberToWords(totalReceipt);
    final double outstandingTotal = previousOs + totalReceipt;

    final formattedTotalReceipt = NumberFormat('#,##,##0.00').format(totalReceipt);
    final formattedPreviousOs = NumberFormat('#,##,##0.00').format(previousOs);
    final formattedOutstandingTotal = NumberFormat('#,##,##0.00').format(outstandingTotal);

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
                      Text('Cash Bank Card Receipt Print Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown)),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: _brownLight),
                  ),
                ],
              ),
            ),

            // Printable Receipt Body
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

                    // Main Outer Receipt Box
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black87, width: 1),
                      ),
                      child: Column(
                        children: [
                          // Top Info Row (Name / Address / Phone Left | Rec No / Date / PAN Right)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left Customer Box
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black87, width: 1),
                                        bottom: BorderSide(color: Colors.black87, width: 1),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Name     : ${name.isNotEmpty ? name : 'CHAMPAK JEWELS'}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                                        const SizedBox(height: 4),
                                        Text('Address : ${address.isNotEmpty ? address : 'NEHRU ROAD,JAMMU,'}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                        const SizedBox(height: 8),
                                        Text('Phone    : $phone', style: const TextStyle(fontSize: 11, color: Colors.black87)),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black54))),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 80, child: Text('Rec. No.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                              const Text(':', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Text(recNo.isNotEmpty ? recNo : 'CBCR / 3', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black54))),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 80, child: Text('Date', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                              const Text(':', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Text(date.isNotEmpty ? date : DateFormat('dd/MM/yyyy').format(DateTime.now()), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 80, child: Text('ITPAN No', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                                              const Text(':', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Text(itPanNo, style: const TextStyle(fontSize: 11)),
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

                          // Particulars Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCDCDC),
                              border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 4, child: Text('Particulars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                                Expanded(flex: 3, child: Text('Cheque / Card No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                                Expanded(flex: 3, child: Text('Bank / Card Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                                Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black))),
                              ],
                            ),
                          ),

                          // Table Body Rows
                          Container(
                            constraints: const BoxConstraints(minHeight: 120),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                            ),
                            child: Column(
                              children: displayRows.map((r) {
                                final double amt = (r['amount'] as double?) ?? double.tryParse(r['amount']?.toString() ?? '') ?? 0.0;
                                final String particulars = r['particulars']?.toString() ?? r['mode']?.toString() ?? 'Cash';
                                final String book = r['book']?.toString() ?? '';
                                final String fullParticulars = book.isNotEmpty && book != particulars ? '$particulars    $book' : particulars;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 4, child: Text(fullParticulars, style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                      Expanded(flex: 3, child: Text(r['refNo']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                      Expanded(flex: 2, child: Text(r['date']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                      Expanded(flex: 3, child: Text(r['bankName']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Colors.black87))),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          NumberFormat('#,##,##0.00').format(amt),
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Amount In Words Bar
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 11, color: Colors.black),
                                children: [
                                  const TextSpan(text: 'Amount In Words: ', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                  TextSpan(text: ' $amountInWords', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),

                          // Sub-middle Breakdown (Receipts Left | Totals Right)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Left Receipts Breakdown Box
                                Expanded(
                                  flex: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        right: BorderSide(color: Colors.black87, width: 1),
                                        bottom: BorderSide(color: Colors.black87, width: 1),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Receipts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Cash:', style: TextStyle(fontSize: 11)),
                                            Text(NumberFormat('#,##,##0.00').format(cashTotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Cheque / D.D.:', style: TextStyle(fontSize: 11)),
                                            Text(NumberFormat('#,##,##0.00').format(chequeTotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Card Details:', style: TextStyle(fontSize: 11)),
                                            Text(NumberFormat('#,##,##0.00').format(cardTotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Right Summary Totals Box
                                Expanded(
                                  flex: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      border: Border(bottom: BorderSide(color: Colors.black87, width: 1)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Total Receipt Cr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text(formattedTotalReceipt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Previous O/s. Cr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text(formattedPreviousOs, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const Divider(height: 8, color: Colors.black54),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text('Outstanding Cr.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text(formattedOutstandingTotal, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Signatures & Page No
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    Column(
                                      children: [
                                        Container(width: 150, height: 1, color: Colors.black87),
                                        const SizedBox(height: 4),
                                        const Text('Authorised Signature', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text('Page No. 1/1', style: TextStyle(fontSize: 10, color: Colors.black54)),
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
                        const SnackBar(content: Text('Printing Cash Bank Card Receipt...'), duration: Duration(seconds: 2)),
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
