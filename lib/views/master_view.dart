import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import '../dialogs/bill_detail_dialog.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'master/c_stock_reports/stock_reports_dummy_data.dart';
import 'master/c_stock_reports/widgets/report_header.dart';
import 'master/c_stock_reports/closing_stock_report_view.dart';
import 'master/c_stock_reports/item_wise_stock_balance_view.dart';
import 'master/c_stock_reports/tag_wise_stock_report_view.dart';
import 'master/c_stock_reports/counter_stock_report_view.dart';
import 'master/c_stock_reports/supplier_stock_report_view.dart';
import '../utils/pdf_stock_report_api.dart';
import 'master/a_daily_reports/daily_activity_report_view.dart';
import 'master/a_daily_reports/daily_reports_sections.dart';
import 'master/b_account_reports/account_reports.dart';
import 'master/b_account_reports/gst_reports.dart';
import 'master/e_approval_consignment_reports/approval_consignment_reports.dart';
import 'master/f_supplier_customer_reports/supplier_customer_reports.dart';
import 'master/g_account_receivable_payable_reports/account_receivable_payable_reports.dart';
import 'master/h_utility_reports/utility_reports.dart';
import 'master/l_full_report/full_report_view.dart';
import 'master/report_shared.dart';
import 'master/d_counter_reports/counter_reports.dart';
import 'master/i_order_repairing_reports/order_repairing_reports.dart';
import 'master/j_custom_report/custom_report_view.dart';
import 'master/k_customize_reports/customize_reports_view.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF6D4C41);
const _border = Color(0xFFE5DDD0);

List<Widget> buildReportMenuItems(
  List<Map<String, dynamic>> items,
  Function(String title) onSelectReport,
) {
  return items.map<Widget>((item) {
    final String title = item['title'] as String;
    final List<Map<String, dynamic>>? children =
        (item['children'] as List?)?.cast<Map<String, dynamic>>();

    if (children != null && children.isNotEmpty) {
      return SubmenuButton(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFFFAF2E9)),
          elevation: WidgetStateProperty.all(6),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFEBDCCB), width: 1.2),
            ),
          ),
        ),
        menuChildren: buildReportMenuItems(children, onSelectReport),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E2723),
            ),
          ),
        ),
      );
    } else {
      return MenuItemButton(
        onPressed: () {
          onSelectReport(title);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF2C3E50),
            ),
          ),
        ),
      );
    }
  }).toList();
}

class MasterView extends StatelessWidget {
  const MasterView({super.key});

  @override
  Widget build(BuildContext context) {
    return const FinancialYearView();
  }
}

class FinancialYearView extends StatefulWidget {
  const FinancialYearView({super.key});

  @override
  State<FinancialYearView> createState() => _FinancialYearViewState();
}

class _FinancialYearViewState extends State<FinancialYearView> {
  DateTime? _fromDate;
  DateTime? _toDate;



  // Tooltip tracking (day number)
  int? _hoveredDay = 14; // Default to showing tooltip on the peak day

  Stream<QuerySnapshot> get _billsStream => FirebaseFirestore.instance
      .collection('bills')
      .snapshots();

  @override
  void initState() {
    super.initState();
    try {
      final file = File('debug_bills.txt');
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('financial_year_settings')
          .doc('active')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['fromDate'] != null) {
              _fromDate = (data['fromDate'] as Timestamp).toDate();
            }
            if (data['toDate'] != null) {
              _toDate = (data['toDate'] as Timestamp).toDate();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading financial year settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both From Date and To Date')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('financial_year_settings')
          .doc('active')
          .set({
        'fromDate': Timestamp.fromDate(_fromDate!),
        'toDate': Timestamp.fromDate(_toDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Financial Year Saved Successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _brown,
              onPrimary: Colors.white,
              onSurface: _brown,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  DateTime? _parseDocDate(Map<String, dynamic> data) {
    if (data['voucherDate'] is Timestamp) {
      return (data['voucherDate'] as Timestamp).toDate();
    }
    if (data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }
    if (data['voucherDate'] != null) {
      final str = data['voucherDate'].toString();
      try {
        return DateFormat('dd/MM/yyyy EEE').parse(str);
      } catch (_) {
        try {
          return DateFormat('dd/MM/yyyy').parse(str);
        } catch (_) {}
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _billsStream,
      builder: (context, snapshot) {
        double receivable = 0.0;
        int receivableParties = 0;
        double payable = 0.0;
        double totalSale = 0.0;

        final start = _fromDate ?? DateTime.now().subtract(const Duration(days: 30));
        final end = _toDate ?? DateTime.now();
        final startMidnight = DateTime(start.year, start.month, start.day);
        final endEnd = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
        int totalDays = endEnd.difference(startMidnight).inDays + 1;
        if (totalDays <= 0) totalDays = 1;

        final bool isMonthly = totalDays > 31;
        List<double> dailySales;
        List<DateTime> chartMonths = [];

        if (isMonthly) {
          var current = DateTime(startMidnight.year, startMidnight.month, 1);
          final endMonth = DateTime(endEnd.year, endEnd.month, 1);
          while (!current.isAfter(endMonth)) {
            chartMonths.add(current);
            current = DateTime(current.year, current.month + 1, 1);
          }
          if (chartMonths.isEmpty) {
            chartMonths.add(startMidnight);
          }
          dailySales = List.generate(chartMonths.length, (index) => 0.0);
        } else {
          dailySales = List.generate(totalDays, (index) => 0.0);
        }

        final List<Map<String, dynamic>> filteredBillsForHistory = [];
        final List<QueryDocumentSnapshot> bills = snapshot.hasData ? snapshot.data!.docs : [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final receivablePartiesSet = <String>{};

          for (final doc in bills) {
            final data = doc.data() as Map<String, dynamic>;
            final vDate = _parseDocDate(data);
            if (vDate == null) continue;

            // Determine bill type: use saved 'billType' field, fallback to voucherNo prefix
            final String billType = data['billType']?.toString() ?? '';
            final String vNo = (data['voucherNo']?.toString() ?? '').replaceAll('/', '-');
            final bool isPurchase = billType == 'Purchase' ||
                (billType.isEmpty && (vNo.startsWith('PR-') || vNo.startsWith('SR-')));

            // 1. Calculate Receivables and Payables
            bool isInFinancialYear = true;
            if (_fromDate != null) {
              final fromMidnight = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
              if (vDate.isBefore(fromMidnight)) isInFinancialYear = false;
            }
            if (_toDate != null) {
              final nowEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
              final effectiveTo = _toDate!.isAfter(nowEnd) ? _toDate! : nowEnd;
              final toEnd = DateTime(effectiveTo.year, effectiveTo.month, effectiveTo.day, 23, 59, 59, 999);
              if (vDate.isAfter(toEnd)) isInFinancialYear = false;
            }

            try {
              final file = File('debug_bills.txt');
              file.writeAsStringSync('id=${doc.id}, vNo=$vNo, billType=$billType, vDate=$vDate, dueAmt=${data['dueAmt']}, dueType=${data['dueAmt']?.runtimeType}, isPurchase=$isPurchase, isInFY=$isInFinancialYear\n', mode: FileMode.append);
            } catch (_) {}

            if (isInFinancialYear) {
              double due = 0.0;
              if (data['dueAmt'] != null) {
                if (data['dueAmt'] is num) {
                  due = (data['dueAmt'] as num).toDouble();
                } else {
                  due = double.tryParse(data['dueAmt'].toString()) ?? 0.0;
                }
              }
              if (due != 0) {
                if (isPurchase) {
                  if (due > 0) {
                    payable += due;
                  } else {
                    receivable += due.abs();
                    final party = data['acName']?.toString() ?? 'Unknown';
                    receivablePartiesSet.add(party);
                  }
                } else {
                  if (due > 0) {
                    receivable += due;
                    final party = data['acName']?.toString() ?? 'Unknown';
                    receivablePartiesSet.add(party);
                  } else {
                    payable += due.abs();
                  }
                }
              }
            }

            // 2. Calculate Monthly/Daily Sales within custom date range
            if (!isPurchase && !vDate.isBefore(startMidnight) && !vDate.isAfter(endEnd)) {
              final double amount = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;
              totalSale += amount;

              if (isMonthly) {
                final monthIndex = (vDate.year - startMidnight.year) * 12 + (vDate.month - startMidnight.month);
                if (monthIndex >= 0 && monthIndex < dailySales.length) {
                  dailySales[monthIndex] += amount;
                }
              } else {
                final dayIndex = vDate.difference(startMidnight).inDays;
                if (dayIndex >= 0 && dayIndex < dailySales.length) {
                  dailySales[dayIndex] += amount;
                }
              }

              // Add to history list
              filteredBillsForHistory.add({
                'id': doc.id,
                'voucherNo': (data['voucherNo'] ?? 'Unknown').toString().replaceAll('/', '-'),
                'voucherDate': vDate,
                'acName': data['acName'] ?? 'Walk-in Customer',
                'salesman': data['salesman'] ?? 'N/A',
                'voucherAmt': amount,
                'paymentAmt': (data['paymentAmt'] as num?)?.toDouble() ?? 0.0,
                'dueAmt': (data['dueAmt'] as num?)?.toDouble() ?? 0.0,
              });
            }
          }
          receivableParties = receivablePartiesSet.length;

          // Adjust _hoveredDay bound to match the chart points length
          final int numPoints = dailySales.length;
          if (_hoveredDay == null || _hoveredDay! < 1 || _hoveredDay! > numPoints) {
            _hoveredDay = (numPoints / 2).round();
          }

          // Sort history by date descending (newest first)
          filteredBillsForHistory.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
        }

        return SelectionArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Summary Cards at the top ───
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total Receivable',
                          amount: receivable,
                          subtitle: receivable > 0
                              ? 'From $receivableParties Party'
                              : 'You don\'t have any receivables.',
                          icon: Icons.arrow_downward_rounded,
                          iconColor: const Color(0xFF2E7D32),
                          iconBgColor: const Color(0xFFE8F5E9),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total Payable',
                          amount: payable,
                          subtitle: payable > 0
                              ? 'To supplier accounts'
                              : 'You don\'t have any payables as of now.',
                          icon: Icons.arrow_upward_rounded,
                          iconColor: const Color(0xFFC62828),
                          iconBgColor: const Color(0xFFFFEBEE),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ─── Graph/Sale Card section ───
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Sale',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7F8C8D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹ ${totalSale.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2C3E50),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SalesLineChart(
                          dailySales: dailySales,
                          selectedDay: _hoveredDay,
                          startDate: startMidnight,
                          isMonthly: isMonthly,
                          onDaySelected: (day) {
                            setState(() {
                              _hoveredDay = day;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── Save Financial Year configurations ───
                  const Divider(color: _border),
                  const SizedBox(height: 24),
                  const Text(
                    'Financial Year Settings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildDateCard(
                        title: 'From Date',
                        date: _fromDate,
                        onTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(width: 20),
                      _buildDateCard(
                        title: 'To Date',
                        date: _toDate,
                        onTap: () => _selectDate(context, false),
                      ),
                      const SizedBox(width: 24),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brown,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Save Financial Year'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return _HoverSummaryCardMaster(
      title: title,
      amount: amount,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      compact: false,
    );
  }



  Widget _buildDateCard({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: _brownLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 14, color: _brown),
                const SizedBox(width: 8),
                Text(
                  date != null
                      ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                      : 'Select Date',
                  style: TextStyle(
                    fontSize: 12,
                    color: date != null ? _brown : Colors.grey,
                    fontWeight:
                        date != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Paint Sales Chart ───
// ─── Custom Paint Sales Chart ───
class SalesLineChart extends StatelessWidget {
  final List<double> dailySales;
  final int? selectedDay;
  final DateTime startDate;
  final bool isMonthly;
  final ValueChanged<int?> onDaySelected;

  const SalesLineChart({
    super.key,
    required this.dailySales,
    required this.selectedDay,
    required this.startDate,
    required this.isMonthly,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartWidth = constraints.maxWidth;
        const chartHeight = 220.0;

        return GestureDetector(
          onPanStart: (details) =>
              _handleGesture(details.localPosition, chartWidth),
          onPanUpdate: (details) =>
              _handleGesture(details.localPosition, chartWidth),
          onTapDown: (details) =>
              _handleGesture(details.localPosition, chartWidth),
          child: CustomPaint(
            size: Size(chartWidth, chartHeight),
            painter: LineChartPainter(
              dailySales: dailySales,
              selectedDay: selectedDay,
              startDate: startDate,
              isMonthly: isMonthly,
            ),
          ),
        );
      },
    );
  }

  void _handleGesture(Offset localPosition, double chartWidth) {
    const leftMargin = 45.0;
    const rightMargin = 20.0;
    final usableWidth = chartWidth - leftMargin - rightMargin;

    if (usableWidth <= 0) return;

    final int len = dailySales.length;
    if (len <= 0) return;

    final x = localPosition.dx - leftMargin;
    double pct = x / usableWidth;
    if (pct < 0) pct = 0;
    if (pct > 1) pct = 1;

    final index = len <= 1 ? 0 : (pct * (len - 1)).round();
    if (index >= 0 && index < len) {
      onDaySelected(index + 1); // 1-indexed offset
    }
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> dailySales;
  final int? selectedDay;
  final DateTime startDate;
  final bool isMonthly;

  LineChartPainter({
    required this.dailySales,
    required this.selectedDay,
    required this.startDate,
    required this.isMonthly,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftMargin = 45.0;
    const rightMargin = 20.0;
    const topMargin = 45.0;
    const bottomMargin = 30.0;

    final usableWidth = size.width - leftMargin - rightMargin;
    final usableHeight = size.height - topMargin - bottomMargin;
    final bottomY = topMargin + usableHeight;

    if (usableWidth <= 0 || usableHeight <= 0) return;

    // Find scaleMax rounded to clean steps
    double maxVal = dailySales.isEmpty ? 0.0 : dailySales.reduce(math.max);
    if (maxVal < 1000) maxVal = 1000;
    double scaleMax = ((maxVal / 5000).ceil() * 5000).toDouble();
    if (scaleMax < 5000) scaleMax = 5000;

    // 1. Draw Grid Lines and Y-Axis Labels
    final gridPaint = Paint()
      ..color = const Color(0xFFF2ECE1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final labelStyle = const TextStyle(
      color: Color(0xFF9E9E9E),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final int yDivisions = 3;
    for (int i = 0; i <= yDivisions; i++) {
      final double val = (scaleMax / yDivisions) * i;
      final double y = bottomY - (val / scaleMax) * usableHeight;

      canvas.drawLine(
          Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      String labelText;
      if (val >= 1000) {
        labelText = '${(val / 1000).toStringAsFixed(0)}k';
      } else {
        labelText = val.toStringAsFixed(0);
      }

      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // 2. Draw X-Axis Labels
    final numPoints = dailySales.length;
    if (numPoints > 0) {
      if (isMonthly) {
        final step = numPoints > 12 ? (numPoints / 6).ceil() : 1;
        for (int i = 0; i < numPoints; i += step) {
          final double x = leftMargin + (numPoints <= 1 ? 0.5 : i / (numPoints - 1)) * usableWidth;
          final date = DateTime(startDate.year, startDate.month + i, 1);
          final labelText = DateFormat("MMM ''yy").format(date);

          final textPainter = TextPainter(
            text: TextSpan(text: labelText, style: labelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, bottomY + 6),
          );
        }
      } else {
        final step = numPoints > 15 ? 3 : (numPoints > 7 ? 2 : 1);
        for (int i = 0; i < numPoints; i += step) {
          final double x = leftMargin + (numPoints <= 1 ? 0.5 : i / (numPoints - 1)) * usableWidth;
          final date = startDate.add(Duration(days: i));
          final labelText = DateFormat('d MMM').format(date);

          final textPainter = TextPainter(
            text: TextSpan(text: labelText, style: labelStyle),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            Offset(x - textPainter.width / 2, bottomY + 6),
          );
        }
      }
    }

    // 3. Draw Bezier Curve and Gradient Fill
    if (numPoints > 1) {
      final path = Path();
      final points = <Offset>[];

      for (int i = 0; i < numPoints; i++) {
        final double x = leftMargin + (numPoints <= 1 ? 0.5 : i / (numPoints - 1)) * usableWidth;
        final double y = bottomY - (dailySales[i] / scaleMax) * usableHeight;
        points.add(Offset(x, y));
      }

      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < numPoints - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final controlX = p0.dx + (p1.dx - p0.dx) / 2;
        path.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
      }

      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, bottomY);
      fillPath.lineTo(points.first.dx, bottomY);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF2196F3).withValues(alpha: 0.22),
            const Color(0xFF2196F3).withValues(alpha: 0.01),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(
            Rect.fromLTRB(leftMargin, topMargin, size.width - rightMargin, bottomY))
        ..style = PaintingStyle.fill;

      canvas.drawPath(fillPath, fillPaint);

      final linePaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(path, linePaint);
    }

    // 4. Draw Selected Day Highlight & Tooltip
    if (selectedDay != null && selectedDay! >= 1 && selectedDay! <= numPoints) {
      final index = selectedDay! - 1;
      final double x = leftMargin + (numPoints <= 1 ? 0.5 : index / (numPoints - 1)) * usableWidth;
      final double y = bottomY - (dailySales[index] / scaleMax) * usableHeight;

      // Vertical dashed line
      final dashPaint = Paint()
        ..color = const Color(0xFF2196F3).withValues(alpha: 0.4)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      double startY = y;
      const dashLength = 4.0;
      const dashSpace = 4.0;
      while (startY < bottomY) {
        canvas.drawLine(
          Offset(x, startY),
          Offset(x, math.min(startY + dashLength, bottomY)),
          dashPaint,
        );
        startY += dashLength + dashSpace;
      }

      // Target circular highlight dot
      final dotPaint = Paint()
        ..color = const Color(0xFF2196F3)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(x, y), 5.5, borderPaint);
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);

      final String amtText = '₹ ${dailySales[index].toStringAsFixed(0)}';
      String dayText;
      if (isMonthly) {
        final date = DateTime(startDate.year, startDate.month + index, 1);
        dayText = DateFormat('MMMM yyyy').format(date);
      } else {
        final date = startDate.add(Duration(days: index));
        dayText = DateFormat('d MMMM yyyy').format(date);
      }

      _drawTooltip(canvas, Offset(x, y), dayText, amtText);
    }
  }

  void _drawTooltip(
      Canvas canvas, Offset target, String topText, String bottomText) {
    final textPainterTop = TextPainter(
      text: TextSpan(
        text: topText,
        style: const TextStyle(
            color: Colors.white, fontSize: 10, fontWeight: FontWeight.normal),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textPainterBottom = TextPainter(
      text: TextSpan(
        text: bottomText,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final tooltipWidth =
        math.max(textPainterTop.width, textPainterBottom.width) + 16;
    const tooltipHeight = 36.0;
    final tooltipRect = Rect.fromLTWH(
      target.dx - tooltipWidth / 2,
      target.dy - tooltipHeight - 12,
      tooltipWidth,
      tooltipHeight,
    );

    // Green bubble background
    final bubblePaint = Paint()
      ..color = const Color(0xFF52D6A4)
      ..style = PaintingStyle.fill;

    final RRect rrect =
        RRect.fromRectAndRadius(tooltipRect, const Radius.circular(6));
    canvas.drawRRect(rrect, bubblePaint);

    // Small pointer triangle at the bottom of the tooltip
    final pointerPath = Path()
      ..moveTo(target.dx - 5, target.dy - 12)
      ..lineTo(target.dx + 5, target.dy - 12)
      ..lineTo(target.dx, target.dy - 6)
      ..close();
    canvas.drawPath(pointerPath, bubblePaint);

    textPainterTop.paint(
      canvas,
      Offset(
        tooltipRect.left + (tooltipWidth - textPainterTop.width) / 2,
        tooltipRect.top + 4,
      ),
    );
    textPainterBottom.paint(
      canvas,
      Offset(
        tooltipRect.left + (tooltipWidth - textPainterBottom.width) / 2,
        tooltipRect.top + 18,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant LineChartPainter oldDelegate) {
    return oldDelegate.dailySales != dailySales ||
        oldDelegate.selectedDay != selectedDay ||
        oldDelegate.startDate != startDate ||
        oldDelegate.isMonthly != isMonthly;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportsView Widget
// ─────────────────────────────────────────────────────────────────────────────
class ReportsView extends StatefulWidget {
  final String selectedReportTitle;
  final ValueChanged<String>? onReportSelected;

  const ReportsView({
    super.key,
    this.selectedReportTitle = 'Account & Bills Report',
    this.onReportSelected,
  });

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  DateTime? _fromDate;
  DateTime? _toDate;

  // Selected date range filter (defaults to current month, will be overridden by loaded financial year range)
  DateTime _filterStartDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _filterEndDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);

  bool _isLoadingReports = true;
  List<StockSummaryItem> _stockSummaryList = [];
  List<ItemWiseStockItem> _itemWiseList = [];
  List<TagWiseStockItem> _tagWiseList = [];
  List<CounterStockItem> _counterStockList = [];
  List<SupplierStockItem> _supplierStockList = [];

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _horizontalScrollCtrl = ScrollController();
  String _selectedCategoryFilter = 'All';
  String _selectedGroupFilter = 'All';
  String _selectedEffectFilter = 'All';
  String _selectedSortOption = 'Date: Newest First';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  List<String> get _yearsList {
    if (_fromDate == null || _toDate == null) {
      return [DateTime.now().year.toString()];
    }
    final start = math.min(_fromDate!.year, _toDate!.year);
    final end = math.max(_fromDate!.year, _toDate!.year);
    final list = <String>[];
    for (int y = start; y <= end; y++) {
      list.add(y.toString());
    }
    if (list.isEmpty) {
      return [start.toString()];
    }
    return list;
  }

  Stream<QuerySnapshot> get _billsStream => FirebaseFirestore.instance
      .collection('bills')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('financial_year_settings')
          .doc('active')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data['fromDate'] != null) {
              _fromDate = (data['fromDate'] as Timestamp).toDate();
              _filterStartDate = _fromDate!;
            }
            if (data['toDate'] != null) {
              _toDate = (data['toDate'] as Timestamp).toDate();
              final nowEnd = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);
              _filterEndDate = _toDate!.isAfter(nowEnd) ? _toDate! : nowEnd;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading financial year settings in reports: $e');
    } finally {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReports = true;
    });

    try {
      final inventorySnap = await FirebaseFirestore.instance.collection('jewelry_inventory').get();
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final urdSnap = await FirebaseFirestore.instance.collection('urd_purchases').get();
      final configSnap = await FirebaseFirestore.instance.collection('closing_stock_configs').get();
      final approvalSnap = await FirebaseFirestore.instance.collection('approval_issue_receipts').get();
      final outsourceSnap = await FirebaseFirestore.instance.collection('outsource_manufacturing_entries').get();
      final customerSnap = await FirebaseFirestore.instance.collection('customer_issue_receipts').get();
      final refinerySnap = await FirebaseFirestore.instance.collection('refinery_issue_receipts').get();

      // Fetch configs from Firestore closing_stock_configs
      final Map<String, List<String>> metalIdPuritiesMap = {};
      final List<String> standardMetalIds = [];

      final Map<String, List<String>> defaults = {
        '18D': ['18D', 'DIAMOND 18KT JEWELLERY', '18K DIAMOND', '750 DIAMOND'],
        '18G': ['18G', 'GOLD 18KT JEWELLERY', '18K GOLD', '750 GOLD', '75.0', '75', '18K', '18', '750'],
        '22G': ['22G', 'GOLD 22KT JEWELLERY', '22K GOLD', '916 GOLD', '91.6', '916', '22K', '22', '22KT', 'chain'],
        '24 KT': ['24 KT', '24KT', 'GOLD 24KT JEWELLERY', 'Gold-24 Trading A/c.', '24K GOLD', '999 GOLD', '99.9', '999', '24K', '24'],
        'DI': ['DI', 'Diamond Trading A/c.', 'DIAMOND', 'DIAMONDS'],
        'S925': ['S925', 'SILVER 925', 'SILVER 925 JEWELLERY', '92.5', '925', 'SILVER'],
        'AL': ['AL', 'ALLOY', 'ALLOYS'],
      };

      if (configSnap.docs.isEmpty) {
        for (final entry in defaults.entries) {
          await FirebaseFirestore.instance.collection('closing_stock_configs').doc(entry.key).set({
            'code': entry.key,
            'purities': entry.value,
          });
          metalIdPuritiesMap[entry.key] = entry.value;
          standardMetalIds.add(entry.key);
        }
      } else {
        for (final doc in configSnap.docs) {
          final data = doc.data();
          final code = data['code']?.toString() ?? doc.id;
          final List<String> purities = List<String>.from(data['purities'] ?? []);
          
          final defaultPurities = defaults[code] ?? [];
          for (final def in defaultPurities) {
            if (!purities.contains(def)) {
              purities.add(def);
            }
          }

          metalIdPuritiesMap[code] = purities;
          standardMetalIds.add(code);
        }
      }

      String mapPurityToMetalIdCode(String purity) {
        final p = purity.toUpperCase().replaceAll('%', '').trim();
        for (final entry in metalIdPuritiesMap.entries) {
          final code = entry.key;
          final list = entry.value;
          for (final val in list) {
            final cleanVal = val.toUpperCase().replaceAll('%', '').trim();
            if (p.contains(cleanVal) || cleanVal.contains(p) || p == cleanVal) {
              return code;
            }
          }
        }
        return purity;
      }

      final List<Map<String, dynamic>> allInvDocs = inventorySnap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      final List<Map<String, dynamic>> allBills = [];
      final Set<String> soldTagIds = {};

      for (final doc in billsSnap.docs) {
        final d = doc.data();
        d['id'] = doc.id;
        
        final status = d['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED') continue;

        final dateStr = d['date']?.toString() ?? '';
        DateTime? billDate;
        try {
          if (dateStr.isNotEmpty) {
            final parts = dateStr.split(' ')[0].split('/');
            if (parts.length == 3) {
              final day = int.tryParse(parts[0]) ?? 1;
              final month = int.tryParse(parts[1]) ?? 1;
              final year = int.tryParse(parts[2]) ?? 2026;
              billDate = DateTime(year, month, day);
            }
          }
        } catch (_) {}
        
        billDate ??= _parseDocDate(d);
        
        if (billDate != null) {
          if (billDate.isAfter(_filterStartDate.subtract(const Duration(days: 1))) &&
              billDate.isBefore(_filterEndDate.add(const Duration(days: 1)))) {
            allBills.add(d);
          }
        }

        // Track sold tag IDs from all Sale invoices
        final isSale = d['billType'] == 'Sale' || 
                       d['type'] == 'Sale' || 
                       (d['voucherNo']?.toString().startsWith('SL') ?? false) || 
                       d['category']?.toString().toLowerCase() == 'customer';
        if (isSale) {
          final items = d['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tId = item['tagId']?.toString().trim() ?? '';
                if (tId.isNotEmpty) {
                  soldTagIds.add(tId);
                }
              }
            }
          }
        }
      }

      // Merge inventory items and Purchase bills (pseudo-inventory documents)
      final Map<String, Map<String, dynamic>> tagMap = {};
      for (final doc in allInvDocs) {
        final tagId = doc['tagId']?.toString().trim() ?? doc['id']?.toString().trim() ?? '';
        if (tagId.isNotEmpty) {
          tagMap[tagId] = doc;
        }
      }

      for (final bill in allBills) {
        final isPurchase = bill['billType'] == 'Purchase' || 
                           bill['type'] == 'Purchase' || 
                           (bill['voucherNo']?.toString().startsWith('PR') ?? false) || 
                           bill['category']?.toString().toLowerCase() == 'supplier';
        if (isPurchase) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                if (tagId.isNotEmpty && !tagMap.containsKey(tagId)) {
                  tagMap[tagId] = {
                    'id': tagId,
                    'tagId': tagId,
                    'barcode': tagId,
                    'name': item['name'] ?? item['productName'] ?? '',
                    'category': item['category'] ?? item['group'] ?? 'Uncategorized',
                    'grossWeight': (item['grossWeight'] as num?)?.toDouble() ?? 0.0,
                    'netWeight': (item['netWeight'] as num?)?.toDouble() ?? 0.0,
                    'purity': item['purity'] ?? '22K',
                    'productStatus': 'Available',
                    'pcs': (item['pcs'] as num?)?.toInt() ?? 1,
                    'pieces': (item['pcs'] as num?)?.toInt() ?? 1,
                    'quantity': (item['pcs'] as num?)?.toInt() ?? 1,
                    'metalRate': (item['rate'] as num?)?.toDouble() ?? 0.0,
                  };
                }
              }
            }
          }
        }
      }

      String getGroupHead(String purity) {
        final p = purity.toUpperCase();
        if (p.contains('22') || p.contains('916')) return 'Precious Gold';
        if (p.contains('18') || p.contains('750')) return 'Precious Gold';
        if (p.contains('925') || p.contains('SILVER')) return 'Silverware & Articles';
        if (p.contains('PLATINUM') || p.contains('950')) return 'Platinum Luxury';
        if (p.contains('DIAMOND') || p.contains('18D') || p.contains('22D')) return 'Diamond Collections';
        return 'Antique Craft';
      }

      String getMetalType(String purity) {
        final p = purity.toUpperCase();
        if (p.contains('22') || p.contains('916')) return 'Gold 22K (916)';
        if (p.contains('18') || p.contains('750')) return 'Gold 18K (750)';
        if (p.contains('925') || p.contains('SILVER')) return 'Silver 925';
        if (p.contains('PLATINUM') || p.contains('950')) return 'Platinum 950';
        if (p.contains('DIAMOND') || p.contains('18D') || p.contains('22D')) return 'Diamond';
        return 'Gold 22K (916)';
      }

      // REPORT 3: TAG WISE STOCK REPORT
      final List<TagWiseStockItem> tagWise = [];
      tagMap.forEach((tagId, doc) {
        final barcode = doc['barcode']?.toString() ?? doc['tagId']?.toString() ?? tagId;
        final name = doc['name']?.toString() ?? doc['productName']?.toString() ?? '';
        final category = doc['category']?.toString() ?? doc['groupName']?.toString() ?? doc['metalId']?.toString() ?? 'Uncategorized';
        final grossWt = (doc['grossWeight'] ?? doc['grossWt'] ?? 0.0).toDouble();
        final netWt = (doc['netWeight'] ?? doc['netWt'] ?? 0.0).toDouble();
        final purity = doc['purity']?.toString() ?? doc['metalId']?.toString() ?? '22K';
        
        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final isYetToAdd = doc['yetToAdd'] == true || doc['isYetToAdd'] == true || rawStatus == 'Yet to add';
        
        final currentPcs = (doc['pcs'] as num?)?.toInt() ?? 
                           (doc['pieces'] as num?)?.toInt() ?? 
                           (doc['quantity'] as num?)?.toInt() ?? 1;

        final isSold = (currentPcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock') ||
                       (soldTagIds.contains(tagId) && 
                        rawStatus.toLowerCase() != 'shop product' && 
                        rawStatus.toLowerCase() != 'available');

        final status = isSold ? 'Sold' : (isYetToAdd ? 'Reserved' : 'Available');
        final counter = doc['counterNo']?.toString() ?? doc['counter']?.toString() ?? doc['counterName']?.toString() ?? 'Main Display Safe';

        tagWise.add(TagWiseStockItem(
          tagNumber: tagId,
          barcode: barcode,
          itemName: name,
          category: category,
          grossWeight: grossWt,
          netWeight: netWt,
          purity: purity,
          status: status,
          counter: counter,
        ));
      });

      // REPORT 2: ITEM WISE STOCK BALANCE
      final Map<String, List<Map<String, dynamic>>> itemWiseGroups = {};
      tagMap.forEach((tagId, doc) {
        final key = doc['tagId']?.toString().trim().toLowerCase() ?? doc['id']?.toString().trim().toLowerCase() ?? tagId.toLowerCase().trim();
        
        itemWiseGroups.putIfAbsent(key, () => []).add(doc);
      });

      // Include sold items from Sale bills
      for (final bill in allBills) {
        final isSale = bill['billType'] == 'Sale' || 
                       bill['type'] == 'Sale' || 
                       (bill['voucherNo']?.toString().startsWith('SL') ?? false) || 
                       bill['category']?.toString().toLowerCase() == 'customer';
        if (isSale) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                final doc = {
                  'id': tagId.isNotEmpty ? tagId : 'sold_non_tagged',
                  'tagId': tagId,
                  'barcode': tagId,
                  'name': item['name'] ?? item['productName'] ?? '',
                  'category': item['category'] ?? item['group'] ?? 'Uncategorized',
                  'grossWeight': (item['grossWeight'] as num?)?.toDouble() ?? 0.0,
                  'netWeight': (item['netWeight'] as num?)?.toDouble() ?? 0.0,
                  'purity': item['purity'] ?? '22K',
                  'productStatus': 'Sold',
                  'isFromBill': true,
                  'pcs': (item['pcs'] as num?)?.toInt() ?? 1,
                  'pieces': (item['pcs'] as num?)?.toInt() ?? 1,
                  'quantity': (item['pcs'] as num?)?.toInt() ?? 1,
                };
                final key = tagId.isNotEmpty ? tagId.toLowerCase().trim() : '${doc['name'].toString().toLowerCase()}_${doc['purity'].toString().toLowerCase()}';
                itemWiseGroups.putIfAbsent(key, () => []).add(doc);
              }
            }
          }
        }
      }

      final List<ItemWiseStockItem> itemWise = [];
      itemWiseGroups.forEach((key, docs) {
        final first = docs.first;
        final name = first['name']?.toString() ?? first['productName']?.toString() ?? '';
        final category = first['category']?.toString() ?? first['groupName']?.toString() ?? first['metalId']?.toString() ?? 'Uncategorized';
        final purity = first['purity']?.toString() ?? first['metalId']?.toString() ?? '22K';
        final branch = first['branch']?.toString() ?? 'Main Branch (Coimbatore)';
        
        int availableQty = 0;
        int soldQty = 0;
        double gross = 0.0;
        double net = 0.0;
        double totalVal = 0.0;
        
        for (final d in docs) {
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? (d['quantity'] as num?)?.toInt() ?? 1;
          final g = (d['grossWeight'] ?? d['grossWt'] ?? 0.0).toDouble();
          final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
          final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

          final dIsSold = rawStatus.toLowerCase() == 'sold' || 
                          rawStatus.toLowerCase() == 'out of stock' ||
                          p <= 0;

          if (dIsSold || d['isFromBill'] == true) {
            if (d['isFromBill'] == true) {
              final soldPcs = p > 0 ? p : 1;
              soldQty += soldPcs;
            }
          } else {
            availableQty += p;
            gross += g * p;
            net += n * p;
            totalVal += (n * p) * rate;
          }
        }

        final int totalQty = availableQty + soldQty;
        final double soldPct = totalQty > 0 ? (soldQty / totalQty * 100) : 0.0;

        // Determine correct product status from available documents first
        Map<String, dynamic>? firstDoc;
        for (final d in docs) {
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? (d['quantity'] as num?)?.toInt() ?? 1;

          final dIsSold = rawStatus.toLowerCase() == 'sold' || 
                          rawStatus.toLowerCase() == 'out of stock' ||
                          p <= 0;
          if (!dIsSold && d['isFromBill'] != true) {
            firstDoc = d;
            break;
          }
        }
        firstDoc ??= first;

        final rawStatus = (firstDoc['productStatus'] ?? firstDoc['status'] ?? '').toString().trim();
        final rawStatusLower = rawStatus.toLowerCase();

        String prodStatus = 'Shop product';
        if (rawStatusLower == 'yet to add' || firstDoc['yetToAdd'] == true || firstDoc['isYetToAdd'] == true) {
          prodStatus = 'Yet to add';
        } else if (rawStatusLower == 'web product') {
          prodStatus = 'Web Product';
        } else if (rawStatusLower == 'website product') {
          prodStatus = 'Website product';
        } else if (rawStatusLower == 'shop product') {
          prodStatus = 'Shop product';
        } else {
          final isWeb = firstDoc['inWebsite'] == true || 
                        firstDoc['uploadInWebsite'] == true || 
                        firstDoc['isWebsiteVisible'] == true || 
                        firstDoc['visibleInWebsite'] == true;
          if (isWeb) {
            prodStatus = 'Website product';
          } else {
            prodStatus = 'Shop product';
          }
        }

        itemWise.add(ItemWiseStockItem(
          itemCode: firstDoc['id']?.toString() ?? '',
          itemName: name,
          category: category,
          purity: purity,
          branch: branch,
          quantity: availableQty,
          grossWeight: gross,
          netWeight: net,
          value: totalVal,
          availableQuantity: availableQty,
          soldQuantity: soldQty,
          totalQuantity: totalQty,
          soldPercentage: soldPct,
          productStatus: prodStatus,
        ));
      });

      // REPORT 1: STOCK SUMMARY REPORT (Closing Stock Report)
      final Map<String, List<Map<String, dynamic>>> summaryGroups = {};
      for (final metalId in standardMetalIds) {
        summaryGroups[metalId] = [];
      }

      tagMap.forEach((tagId, doc) {
        final metalId = doc['metalId']?.toString() ?? '';
        final metalGroupName = doc['metalGroupName']?.toString() ?? doc['groupName']?.toString() ?? doc['category']?.toString() ?? '';
        final purity = doc['purity']?.toString() ?? '';
        
        String key = '';
        if (metalId.isNotEmpty) {
          key = mapPurityToMetalIdCode(metalId);
        }
        if (key.isEmpty || !standardMetalIds.contains(key)) {
          if (metalGroupName.isNotEmpty) {
            key = mapPurityToMetalIdCode(metalGroupName);
          }
        }
        if (key.isEmpty || !standardMetalIds.contains(key)) {
          if (purity.isNotEmpty) {
            key = mapPurityToMetalIdCode(purity);
          }
        }
        if (key.isEmpty || !standardMetalIds.contains(key)) {
          key = '22G'; // fallback
        }
        summaryGroups.putIfAbsent(key, () => []).add(doc);
      });

      final Map<String, int> stockOutMap = {};
      final Map<String, int> stockInMap = {};

      for (final bill in allBills) {
        final items = bill['items'] as List?;
        final isSale = bill['billType'] == 'Sale' || bill['type'] == 'Sale';
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final purity = item['purity']?.toString() ?? '';
              final group = item['group']?.toString() ?? item['groupName']?.toString() ?? item['category']?.toString() ?? '';
              
              String key = '';
              if (group.isNotEmpty) {
                key = mapPurityToMetalIdCode(group);
              }
              if (key.isEmpty || !standardMetalIds.contains(key)) {
                if (purity.isNotEmpty) {
                  key = mapPurityToMetalIdCode(purity);
                }
              }
              if (key.isEmpty || !standardMetalIds.contains(key)) {
                key = '22G'; // fallback
              }
              
              final pcs = (item['pcs'] as num?)?.toInt() ?? 1;
              if (isSale) {
                stockOutMap[key] = (stockOutMap[key] ?? 0) + pcs;
              } else {
                stockInMap[key] = (stockInMap[key] ?? 0) + pcs;
              }
            }
          }
        }
      }

      // Sum weights of sold items from sales bills for untagged items
      final Map<String, double> salesWeightMap = {};
      // Sum weights of purchased items from purchase bills for untagged items
      final Map<String, double> purchaseWeightMap = {};

      for (final bill in allBills) {
        final isSale = bill['billType'] == 'Sale' || 
                       bill['type'] == 'Sale' || 
                       (bill['voucherNo']?.toString().startsWith('SL') ?? false) || 
                       bill['category']?.toString().toLowerCase() == 'customer';
        final isPurchase = bill['billType'] == 'Purchase' || 
                           bill['type'] == 'Purchase' || 
                           (bill['voucherNo']?.toString().startsWith('PR') ?? false) || 
                           bill['category']?.toString().toLowerCase() == 'supplier';
        
        if (isSale) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                if (tagId.isEmpty) {
                  final purity = item['purity']?.toString() ?? '';
                  final group = item['group']?.toString() ?? item['groupName']?.toString() ?? item['category']?.toString() ?? '';
                  
                  String key = '';
                  if (group.isNotEmpty) {
                    key = mapPurityToMetalIdCode(group);
                  }
                  if (key.isEmpty || !standardMetalIds.contains(key)) {
                    if (purity.isNotEmpty) {
                      key = mapPurityToMetalIdCode(purity);
                    }
                  }
                  if (key.isEmpty || !standardMetalIds.contains(key)) {
                    key = '22G'; // fallback
                  }
                  final netWt = (item['netWeight'] as num?)?.toDouble() ?? (item['netWt'] as num?)?.toDouble() ?? 0.0;
                  final pcs = (item['pcs'] as num?)?.toInt() ?? (item['pieces'] as num?)?.toInt() ?? 1;
                  salesWeightMap[key] = (salesWeightMap[key] ?? 0.0) + (netWt * pcs);
                }
              }
            }
          }
        } else if (isPurchase) {
          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final tagId = item['tagId']?.toString().trim() ?? '';
                if (tagId.isEmpty) {
                  final purity = item['purity']?.toString() ?? '';
                  final group = item['group']?.toString() ?? item['groupName']?.toString() ?? item['category']?.toString() ?? '';
                  
                  String key = '';
                  if (group.isNotEmpty) {
                    key = mapPurityToMetalIdCode(group);
                  }
                  if (key.isEmpty || !standardMetalIds.contains(key)) {
                    if (purity.isNotEmpty) {
                      key = mapPurityToMetalIdCode(purity);
                    }
                  }
                  if (key.isEmpty || !standardMetalIds.contains(key)) {
                    key = '22G'; // fallback
                  }
                  final netWt = (item['netWeight'] as num?)?.toDouble() ?? (item['netWt'] as num?)?.toDouble() ?? 0.0;
                  final pcs = (item['pcs'] as num?)?.toInt() ?? (item['pieces'] as num?)?.toInt() ?? 1;
                  purchaseWeightMap[key] = (purchaseWeightMap[key] ?? 0.0) + (netWt * pcs);
                }
              }
            }
          }
        }
      }

      // Sum weights of purchased Old Gold items from urd_purchases
      final Map<String, double> urdWeightMap = {};
      for (final doc in urdSnap.docs) {
        final d = doc.data();
        final items = d['items'] as List?;
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final group = item['group']?.toString() ?? '22K';
              final netWt = (item['netWt'] as num?)?.toDouble() ?? 0.0;
              final pcs = (item['pcs'] as num?)?.toInt() ?? (item['pieces'] as num?)?.toInt() ?? 1;
              final key = mapPurityToMetalIdCode(group);
              urdWeightMap[key] = (urdWeightMap[key] ?? 0.0) + (netWt * pcs);
            }
          }
        }
      }

      final Map<String, double> ownCustMap = {};
      final Map<String, double> ownSupMap = {};
      final Map<String, double> custWithUsMap = {};
      final Map<String, double> supWithUsMap = {};

      DateTime? parseDocDateTime(dynamic d) {
        final dateVal = d['date'];
        if (dateVal is Timestamp) return dateVal.toDate();
        if (dateVal is String && dateVal.isNotEmpty) {
          try {
            return DateTime.parse(dateVal);
          } catch (_) {}
        }
        final createdVal = d['createdAt'];
        if (createdVal is Timestamp) return createdVal.toDate();
        return null;
      }

      bool isWithinDateRange(DateTime? date) {
        if (date == null) return true;
        return date.isAfter(_filterStartDate.subtract(const Duration(days: 1))) &&
               date.isBefore(_filterEndDate.add(const Duration(days: 1)));
      }

      // Column B: Own Stock With Customer (approval_issue_receipts)
      for (final doc in approvalSnap.docs) {
        final d = doc.data();
        final status = d['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED') continue;

        final date = parseDocDateTime(d);
        if (!isWithinDateRange(date)) continue;

        final type = d['transactionType']?.toString() ?? '';
        final itemName = d['itemName']?.toString() ?? '';
        final netWeight = (d['netWeight'] as num?)?.toDouble() ?? 0.0;
        final key = mapPurityToMetalIdCode(itemName);

        final double direction = type.toLowerCase().contains('issue') ? 1.0 : -1.0;
        ownCustMap[key] = (ownCustMap[key] ?? 0.0) + (netWeight * direction);
      }

      // Column C: Own Stock With Supplier (outsource_manufacturing_entries)
      for (final doc in outsourceSnap.docs) {
        final d = doc.data();
        final status = d['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED') continue;

        final date = parseDocDateTime(d);
        if (!isWithinDateRange(date)) continue;

        final type = d['transactionType']?.toString() ?? '';
        final double direction = type.toLowerCase().contains('issue') ? 1.0 : -1.0;

        final items = d['items'] as List?;
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final itemName = item['itemName']?.toString() ?? '';
              final netWeight = (item['netWeight'] as num?)?.toDouble() ?? 0.0;
              final key = mapPurityToMetalIdCode(itemName);
              ownSupMap[key] = (ownSupMap[key] ?? 0.0) + (netWeight * direction);
            }
          }
        }
      }

      // Column D: Customer Stock With Us (customer_issue_receipts)
      for (final doc in customerSnap.docs) {
        final d = doc.data();
        final status = d['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED') continue;

        final date = parseDocDateTime(d);
        if (!isWithinDateRange(date)) continue;

        final type = d['transactionType']?.toString() ?? '';
        final double direction = type.toLowerCase().contains('receipt') ? 1.0 : -1.0;

        final items = d['items'] as List?;
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final itemName = item['itemName']?.toString() ?? '';
              final netWeight = (item['netWeight'] as num?)?.toDouble() ?? 0.0;
              final key = mapPurityToMetalIdCode(itemName);
              custWithUsMap[key] = (custWithUsMap[key] ?? 0.0) + (netWeight * direction);
            }
          }
        }
      }

      // Column E: Supplier Stock With Us (refinery_issue_receipts)
      for (final doc in refinerySnap.docs) {
        final d = doc.data();
        final status = d['status']?.toString().toUpperCase() ?? '';
        if (status == 'CANCELLED') continue;

        final date = parseDocDateTime(d);
        if (!isWithinDateRange(date)) continue;

        final type = d['transactionType']?.toString() ?? '';
        final itemName = d['itemName']?.toString() ?? '';
        final netWeight = (d['netWeight'] as num?)?.toDouble() ?? 0.0;
        final key = mapPurityToMetalIdCode(itemName);

        final double direction = type.toLowerCase().contains('receipt') ? 1.0 : -1.0;
        supWithUsMap[key] = (supWithUsMap[key] ?? 0.0) + (netWeight * direction);
      }

      final List<StockSummaryItem> stockSummary = [];
      summaryGroups.forEach((key, docs) {
        final purity = key;
        final category = purity;
        
        final groupHead = getGroupHead(purity);
        final metalType = getMetalType(purity);
        final branch = docs.isNotEmpty
            ? (docs.first['branch']?.toString() ?? 'Main Branch (Coimbatore)')
            : 'Main Branch (Coimbatore)';

        int activeQty = 0;
        double totalWt = 0.0;
        double totalVal = 0.0;

        for (final d in docs) {
          final docId = d['tagId']?.toString().trim() ?? d['id']?.toString().trim() ?? '';
          final rawStatus = d['productStatus']?.toString() ?? d['status']?.toString() ?? '';
          final currentPcs = (d['pcs'] as num?)?.toInt() ?? 
                             (d['pieces'] as num?)?.toInt() ?? 
                             (d['quantity'] as num?)?.toInt() ?? 1;

          final isSold = (currentPcs <= 0 || 
                         rawStatus.toLowerCase() == 'sold' || 
                         rawStatus.toLowerCase() == 'out of stock') ||
                         (soldTagIds.contains(docId) && 
                          rawStatus.toLowerCase() != 'shop product' && 
                          rawStatus.toLowerCase() != 'available');
          if (isSold) continue;

          final p = currentPcs;
          final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
          final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

          activeQty += p;
          totalWt += n * p;
          totalVal += n * p * rate;
        }

        final inQty = stockInMap[key] ?? 0;
        final outQty = stockOutMap[key] ?? 0;
        final opening = activeQty - inQty + outQty;

        // Apply dynamic stock updates: add Old Gold, subtract untagged Sales
        final double urdWt = urdWeightMap[key] ?? 0.0;
        final double salesWt = salesWeightMap[key] ?? 0.0;
        final double purWt = purchaseWeightMap[key] ?? 0.0;
        totalWt = totalWt + urdWt + purWt - salesWt;

        stockSummary.add(StockSummaryItem(
          groupHead: groupHead,
          category: category,
          metalType: metalType,
          branch: branch,
          itemCount: docs.length,
          openingQty: opening >= 0 ? opening : 0,
          stockIn: inQty,
          stockOut: outQty,
          closingQty: activeQty,
          weight: totalWt,
          value: totalVal,
          ownCust: ownCustMap[key] ?? 0.0,
          ownSup: ownSupMap[key] ?? 0.0,
          custWithUs: custWithUsMap[key] ?? 0.0,
          supWithUs: supWithUsMap[key] ?? 0.0,
        ));
      });

      try {
        final logFile = File('c:/FlutterProjects/trilokk/Trilok_MCET/scratch_log.txt');
        final buffer = StringBuffer();
        buffer.writeln('=== DIAGNOSTICS ===');
        buffer.writeln('Active range: $_filterStartDate to $_filterEndDate');
        buffer.writeln('allInvDocs count: ${allInvDocs.length}');
        for (final doc in allInvDocs) {
          buffer.writeln('tagId: ${doc['tagId']}, id: ${doc['id']}, purity: ${doc['purity']}, status: ${doc['productStatus'] ?? doc['status']}, netWt: ${doc['netWeight'] ?? doc['netWt']}, pcs: ${doc['pcs']}');
        }
        buffer.writeln('soldTagIds: ${soldTagIds.toList()}');
        
        buffer.writeln('=== BILLS LOG ===');
        for (final doc in billsSnap.docs) {
          final d = doc.data();
          final status = d['status']?.toString() ?? '';
          final type = d['billType'] ?? d['type'] ?? '';
          final voucherNo = d['voucherNo'] ?? '';
          final dateStr = d['date'] ?? '';
          final items = d['items'] as List?;
          buffer.writeln('Bill: $voucherNo, type: $type, status: $status, date: $dateStr');
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                buffer.writeln('  - Item tagId: ${item['tagId']}, name: ${item['name'] ?? item['productName']}, netWt: ${item['netWeight'] ?? item['netWt']}');
              }
            }
          }
        }
        
        await logFile.writeAsString(buffer.toString());
      } catch (e) {
        debugPrint('Diagnostics write error: $e');
      }

      // REPORT 4: COUNTER STOCK REPORT
      final Map<String, List<Map<String, dynamic>>> counterGroups = {};
      tagMap.forEach((tagId, doc) {
        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final currentPcs = (doc['pcs'] as num?)?.toInt() ?? 
                           (doc['pieces'] as num?)?.toInt() ?? 
                           (doc['quantity'] as num?)?.toInt() ?? 1;

        final isSold = (currentPcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock') ||
                       (soldTagIds.contains(tagId) && 
                        rawStatus.toLowerCase() != 'shop product' && 
                        rawStatus.toLowerCase() != 'available');
        if (isSold) return;

        final counter = doc['counterNo']?.toString() ?? doc['counter']?.toString() ?? doc['counterName']?.toString() ?? 'Main Display Safe';
        counterGroups.putIfAbsent(counter, () => []).add(doc);
      });

      final List<CounterStockItem> counterStock = [];
      counterGroups.forEach((counter, docs) {
        final Map<String, List<Map<String, dynamic>>> catGroups = {};
        for (final d in docs) {
          final category = d['category']?.toString() ?? d['groupName']?.toString() ?? 'Uncategorized';
          catGroups.putIfAbsent(category, () => []).add(d);
        }

        catGroups.forEach((category, catDocs) {
          int qty = 0;
          double wt = 0.0;
          double val = 0.0;
          for (final d in catDocs) {
            final p = (d['pcs'] as num?)?.toInt() ?? (d['pieces'] as num?)?.toInt() ?? 1;
            final n = (d['netWeight'] ?? d['netWt'] ?? 0.0).toDouble();
            final rate = (d['metalRate'] ?? d['todaysRate'] ?? d['costRate'] ?? d['rate'] ?? 6500.0).toDouble();

            qty += p;
            wt += n * p;
            val += n * p * rate;
          }

          counterStock.add(CounterStockItem(
            counterName: counter,
            staff: 'Staff Assigned',
            category: category,
            itemCount: catDocs.length,
            quantity: qty,
            weight: wt,
            value: val,
          ));
        });
      });

      // REPORT 5: SUPPLIER STOCK REPORT
      final suppliersSnap = await FirebaseFirestore.instance.collection('suppliers').get();
      final Map<String, String> supplierNameMap = {};
      for (final doc in suppliersSnap.docs) {
        final d = doc.data();
        final code = d['supplierCode']?.toString().trim() ?? doc.id;
        final name = d['companyName']?.toString().trim() ?? d['contactName']?.toString().trim() ?? doc.id;
        if (code.isNotEmpty) {
          supplierNameMap[code] = name;
        }
      }

      String getPrefixFromTag(String tagId) {
        final clean = tagId.trim();
        final match = RegExp(r'^[A-Za-z]+').firstMatch(clean);
        if (match != null) {
          return match.group(0)!.toUpperCase();
        }
        return '—';
      }

      final Map<String, int> purPcsMap = {};
      final Map<String, double> purGrossMap = {};
      final Map<String, double> purNetMap = {};
      final Map<String, double> purDiaMap = {};
      final Map<String, double> purStnMap = {};

      final Map<String, int> tagPcsMap = {};
      final Map<String, double> tagGrossMap = {};
      final Map<String, double> tagNetMap = {};
      final Map<String, double> tagDiaMap = {};
      final Map<String, double> tagStnMap = {};

      final Map<String, int> actPcsMap = {};
      final Map<String, double> actGrossMap = {};
      final Map<String, double> actNetMap = {};
      final Map<String, double> actDiaMap = {};
      final Map<String, double> actStnMap = {};

      final Map<String, Map<String, String>> keyDetailsMap = {};

      for (final bill in allBills) {
        final isPurchase = bill['billType'] == 'Purchase' || 
                           bill['type'] == 'Purchase' || 
                           (bill['voucherNo']?.toString().startsWith('PR') ?? false) || 
                           bill['category']?.toString().toLowerCase() == 'supplier';
        if (isPurchase) {
          final supCode = (bill['supplierDetails']?['supplierCode'] ?? bill['supplierDetails']?['id'] ?? bill['supplierCode'] ?? '').toString().trim();
          if (supCode.isEmpty) continue;

          if (!supplierNameMap.containsKey(supCode)) {
            final name = (bill['supplierDetails']?['name'] ?? bill['acName'] ?? '').toString().trim();
            if (name.isNotEmpty) {
              supplierNameMap[supCode] = name;
            }
          }

          final items = bill['items'] as List?;
          if (items != null) {
            for (final item in items) {
              if (item is Map) {
                final pcs = (item['pcs'] as num?)?.toInt() ?? 1;
                final gross = (item['grossWeight'] as num?)?.toDouble() ?? 0.0;
                final net = (item['netWeight'] as num?)?.toDouble() ?? 0.0;

                double diaWt = 0.0;
                double stnWt = 0.0;
                final extra = item['extraCharges'] as List?;
                if (extra != null) {
                  for (final ex in extra) {
                    if (ex is Map) {
                      final style = ex['styleName']?.toString().toLowerCase() ?? '';
                      final wt = (ex['weight'] as num?)?.toDouble() ?? 0.0;
                      if (style.contains('diamond') || style.contains('dm')) {
                        diaWt += wt;
                      } else if (style.contains('stone') || style.contains('st')) {
                        stnWt += wt;
                      }
                    }
                  }
                }

                final prefix = getPrefixFromTag(item['tagId']?.toString() ?? '');
                final group = (item['group'] ?? item['category'] ?? item['purity'] ?? 'Uncategorized').toString().trim();
                final key = '${supCode}_${prefix}_$group';

                keyDetailsMap[key] = {
                  'supCode': supCode,
                  'prefix': prefix,
                  'group': group,
                };

                purPcsMap[key] = (purPcsMap[key] ?? 0) + pcs;
                purGrossMap[key] = (purGrossMap[key] ?? 0.0) + gross;
                purNetMap[key] = (purNetMap[key] ?? 0.0) + net;
                purDiaMap[key] = (purDiaMap[key] ?? 0.0) + diaWt;
                purStnMap[key] = (purStnMap[key] ?? 0.0) + stnWt;
              }
            }
          }
        }
      }

      for (final doc in allInvDocs) {
        final supCode = doc['supplierCode']?.toString().trim() ?? '';
        if (supCode.isEmpty) continue;

        final pcs = (doc['pcs'] as num?)?.toInt() ?? 
                    (doc['pieces'] as num?)?.toInt() ?? 
                    (doc['quantity'] as num?)?.toInt() ?? 1;
        final gross = (doc['grossWt'] ?? doc['grossWeight'] ?? 0.0).toDouble();
        final net = (doc['netWt'] ?? doc['netWeight'] ?? 0.0).toDouble();
        final dia = (doc['diamondWt'] ?? 0.0).toDouble();
        final stn = (doc['extraStoneWt'] ?? 0.0).toDouble();

        final prefix = getPrefixFromTag(doc['tagId']?.toString() ?? doc['barcode']?.toString() ?? '');
        final group = (doc['metalGroupName'] ?? doc['groupName'] ?? doc['category'] ?? 'Uncategorized').toString().trim();
        final key = '${supCode}_${prefix}_$group';

        keyDetailsMap[key] = {
          'supCode': supCode,
          'prefix': prefix,
          'group': group,
        };

        tagPcsMap[key] = (tagPcsMap[key] ?? 0) + pcs;
        tagGrossMap[key] = (tagGrossMap[key] ?? 0.0) + gross * pcs;
        tagNetMap[key] = (tagNetMap[key] ?? 0.0) + net * pcs;
        tagDiaMap[key] = (tagDiaMap[key] ?? 0.0) + dia;
        tagStnMap[key] = (tagStnMap[key] ?? 0.0) + stn;

        final rawStatus = doc['productStatus']?.toString() ?? doc['status']?.toString() ?? '';
        final docId = doc['tagId']?.toString().trim() ?? doc['id']?.toString().trim() ?? '';
        final isSold = pcs <= 0 || 
                       rawStatus.toLowerCase() == 'sold' || 
                       rawStatus.toLowerCase() == 'out of stock' ||
                       (soldTagIds.contains(docId) && 
                        rawStatus.toLowerCase() != 'shop product' && 
                        rawStatus.toLowerCase() != 'available');
        if (!isSold) {
          actPcsMap[key] = (actPcsMap[key] ?? 0) + pcs;
          actGrossMap[key] = (actGrossMap[key] ?? 0.0) + gross * pcs;
          actNetMap[key] = (actNetMap[key] ?? 0.0) + net * pcs;
          actDiaMap[key] = (actDiaMap[key] ?? 0.0) + dia;
          actStnMap[key] = (actStnMap[key] ?? 0.0) + stn;
        }
      }

      final List<SupplierStockItem> supplierStock = [];
      for (final key in keyDetailsMap.keys) {
        final details = keyDetailsMap[key]!;
        final code = details['supCode']!;
        final prefix = details['prefix']!;
        final group = details['group']!;
        final name = supplierNameMap[code] ?? code;

        supplierStock.add(SupplierStockItem(
          supplierCode: code,
          supplierName: name,
          tagPrefix: prefix,
          groupName: group,
          purchasedPcs: purPcsMap[key] ?? 0,
          purchasedGrossWt: purGrossMap[key] ?? 0.0,
          purchasedNetWt: purNetMap[key] ?? 0.0,
          purchasedDiamondWt: purDiaMap[key] ?? 0.0,
          purchasedStoneWt: purStnMap[key] ?? 0.0,
          taggedPcs: tagPcsMap[key] ?? 0,
          taggedGrossWt: tagGrossMap[key] ?? 0.0,
          taggedNetWt: tagNetMap[key] ?? 0.0,
          taggedDiamondWt: tagDiaMap[key] ?? 0.0,
          taggedStoneWt: tagStnMap[key] ?? 0.0,
          activePcs: actPcsMap[key] ?? 0,
          activeGrossWt: actGrossMap[key] ?? 0.0,
          activeNetWt: actNetMap[key] ?? 0.0,
          activeDiamondWt: actDiaMap[key] ?? 0.0,
          activeStoneWt: actStnMap[key] ?? 0.0,
        ));
      }

      if (mounted) {
        setState(() {
          _stockSummaryList = stockSummary;
          _itemWiseList = itemWise;
          _tagWiseList = tagWise;
          _counterStockList = counterStock;
          _supplierStockList = supplierStock;
          _isLoadingReports = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading stock reports data: $e');
      if (mounted) {
        setState(() {
          _isLoadingReports = false;
        });
      }
    }
  }

  DateTime? _parseDocDate(Map<String, dynamic> data) {
    if (data['voucherDate'] is Timestamp) {
      return (data['voucherDate'] as Timestamp).toDate();
    }
    if (data['createdAt'] is Timestamp) {
      return (data['createdAt'] as Timestamp).toDate();
    }
    if (data['voucherDate'] != null) {
      final str = data['voucherDate'].toString();
      try {
        return DateFormat('dd/MM/yyyy EEE').parse(str);
      } catch (_) {
        try {
          return DateFormat('dd/MM/yyyy').parse(str);
        } catch (_) {}
      }
    }
    return null;
  }

  String get _selectedFinancialYear {
    if (_fromDate != null && _toDate != null) {
      if (_fromDate!.year == _toDate!.year) {
        return '${_fromDate!.year} - ${_fromDate!.year + 1}';
      }
      return '${_fromDate!.year} - ${_toDate!.year}';
    }
    return '2025 - 2026';
  }

  bool get _isStockReport {
    return true;
  }

  Widget _buildStockReportView(String fullTitle) {
    final title = fullTitle.replaceFirst(RegExp(r'^[A-Z]\s+'), '');

    // All "A Daily Reports" sub-sections and Master Settings manage their own header bar — bypass ReportHeader
    if (_isDailyReportSection(title) || title.contains('Financial Year Settings')) {
      return _buildStockReportBody(title);
    }

    return Column(
      children: [
        ReportHeader(
          title: title,
          selectedFinancialYear: _selectedFinancialYear,
          onFinancialYearChanged: (fy) {},
          startDate: _filterStartDate,
          endDate: _filterEndDate,
          onDateRangeChanged: (range) {
            setState(() {
              _filterStartDate = range.start;
              _filterEndDate = range.end;
            });
            _loadReportData();
          },
          onExportPdf: () => _handleStockReportPdf(title, isPrintMode: false),
          onExportExcel: () => _handleStockReportExcel(title),
          onPrint: () => _handleStockReportPdf(title, isPrintMode: true),
          onReportSelected: (newTitle) {
            widget.onReportSelected?.call(newTitle);
          },
        ),
        Expanded(
          child: _isLoadingReports
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3E2723)),
                  ),
                )
              : _buildStockReportBody(title),
        ),
      ],
    );
  }

  /// Returns true for every "A Daily Reports" sub-section that owns its own
  /// header bar and must NOT be wrapped in the outer ReportHeader.
  bool _isDailyReportSection(String title) =>
      title.contains('Daily Activity Report') ||
      title.contains('Daily Statement') ||
      title.contains('Item Wise Report') ||
      title.contains('Monthly Summary Report') ||
      title.contains('Voucher Print') ||
      // B Account Reports
      title.contains('Ledger / Account Statement') ||
      title.contains('Day Book Report') ||
      title.contains('Cash / Bank Book Report') ||
      title.contains('Trial Balance Report') ||
      title.contains('Profit & Loss Account') ||
      title.contains('Balance Sheet Report') ||
      title.contains('Group Summary Report') ||
      title.contains('GST Exception') ||
      title.contains('GST Summary') ||
      title.contains('Ratewise') ||
      title.contains('Advance Receipt') ||
      title.contains('Reverse Charge') ||
      title.contains('RCM') ||
      title.contains('Pending Approval') ||
      title.contains('Supplier O/s') ||
      title.contains('GST Return') ||
      title.contains('GSTR-1') ||
      title.contains('GSTR-3B') ||
      title.contains('GSTR-9') ||
      title.contains('GST Report') ||
      // E Approval / Consignment Reports
      title.contains('Approval Pending Register') ||
      title.contains('Consignment Issue / Receipt Report') ||
      // G Account Receivable / Payable Reports
      title.contains('Account & Bills Report') ||
      title.contains('Accounts Receivable Summary') ||
      title.contains('Accounts Payable Summary') ||
      title.contains('Outstanding Aging Report') ||
      title.contains('Sales Register') ||
      title.contains('Purchase Register') ||
      title.contains('Supplier Issue Register') ||
      title.contains('Supplier Receipt Register') ||
      title.contains('Customer Issue Register') ||
      title.contains('Customer Receipt Register') ||
      title.contains('Refinery Issue Register') ||
      title.contains('Refinery Receipt Register') ||
      title.contains('Sales Return Register') ||
      title.contains('Purchase Return Register') ||
      title.contains('Supplier Approval Challan Register') ||
      title.contains('Supplier Approval Challan Rate Fixing Register') ||
      title.contains('Credit Note Register') ||
      title.contains('Debit Note Register') ||
      title.contains('Inward Service Register') ||
      title.contains('Outward Service Register') ||
      title.contains('Add/Less Split Transfer Label Report') ||
      title.contains('Cash Receipt Exception Report') ||
      title.contains('PAN Card Exception Report') ||
      // H Utility Reports
      title.contains('Audit Trail Report') ||
      title.contains('System Activity Log') ||
      // F Supplier / Customer Reports — own their header bar
      title.contains('Supplier Outstanding Report') ||
      title.contains('Customer Outstanding Report') ||
      title.contains('Supplier Ledger Summary') ||
      title.contains('Customer Ledger Summary') ||
      // D Counter Reports
      title.contains('Counter Sales Summary') ||
      title.contains('Counter Stock Movement') ||
      title.contains('Full Report') ||
      // I Order / Repairing Reports
      title.contains('Order Status Report') ||
      title.contains('Repairing Job Register') ||
      // J Custom Report
      title.contains('Custom User Report') ||
      // Category Headers
      title.contains('Daily Reports') ||
      title.contains('Account Reports') ||
      title.contains('Stock Reports') ||
      title.contains('Counter Reports') ||
      title.contains('Approval / Consignment Reports') ||
      title.contains('Supplier / Customer Reports') ||
      title.contains('Account Receivable / Payable Reports') ||
      title.contains('Utility Reports') ||
      title.contains('Order / Repairing Reports') ||
      title.contains('Custom Report') ||
      title.contains('Customize Reports') ||
      title.contains('Master Settings') ||
      title.contains('Fix Format Register') ||
      title.contains('Register') ||
      // K Customize Reports
      title.contains('Report Designer / Template Settings');

  Widget _buildStockReportBody(String title) {
    void onReportSelected(String newTitle) {
      widget.onReportSelected?.call(newTitle);
    }

    if (title.contains('Financial Year Settings')) {
      return const FinancialYearView();
    }

    // ── A Daily Reports ───────────────────────────────────────────────────────
    if (title.contains('Daily Activity Report')) {
      return DailyActivityReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Daily Statement')) {
      return DailyStatementView(onReportSelected: onReportSelected);
    } else if (title.contains('Item Wise Report')) {
      return ItemGroupAlloysView(onReportSelected: onReportSelected);
    } else if (title.contains('Monthly Summary Report')) {
      return MonthlySummaryView(onReportSelected: onReportSelected);
    } else if (title.contains('Voucher Print')) {
      return VoucherPrintView(onReportSelected: onReportSelected);
    // ── B Account Reports ─────────────────────────────────────────────────────
    } else if (title.contains('Ledger / Account Statement')) {
      return LedgerAccountStatementView(onReportSelected: onReportSelected);
    } else if (title.contains('Day Book Report')) {
      return DayBookReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Cash / Bank Book Report')) {
      return CashBankBookReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Trial Balance Report')) {
      return TrialBalanceReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Profit & Loss Account')) {
      return ProfitLossAccountView(onReportSelected: onReportSelected);
    } else if (title.contains('Balance Sheet Report')) {
      return BalanceSheetReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Group Summary Report')) {
      return GroupSummaryReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Amount Details')) {
      return AmountDetailsView(
        from: _filterStartDate,
        to: _filterEndDate,
        onReportSelected: onReportSelected,
      );
    // ── GST Reports ──────────────────────────────────────────────────────────
    } else if (title.contains('GST Ratewise Summary Report') || title.contains('Ratewise')) {
      return GstRatewiseSummaryReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GST Exception Report') || (title.contains('Exception Report') && !title.contains('Cash') && !title.contains('PAN'))) {
      return GstExceptionReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GST Advance Receipt Report') || title.contains('Advance Receipt')) {
      return GstAdvanceReceiptReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GST Reverse Charge Report') || title.contains('Reverse Charge') || title.contains('RCM')) {
      return GstReverseChargeReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Pending Approval Report (GST)') || title.contains('Pending Approval Report')) {
      return GstPendingApprovalReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Pending Supplier O/s. Report (GST)') || title.contains('Pending Supplier O/s')) {
      return GstPendingSupplierOsReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GST Summary Report') || title.contains('GST Summary')) {
      return GstSummaryReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GSTR-1')) {
      return Gstr1ReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GSTR-3B')) {
      return Gstr3bReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GSTR-9')) {
      return Gstr9AnnualReportView(onReportSelected: onReportSelected);
    } else if (title.contains('GST Return') || title.contains('GST Report')) {
      return GstReturnReportView(onReportSelected: onReportSelected);
    // ── E Approval / Consignment Reports ──────────────────────────────────────
    } else if (title.contains('Approval Pending Register')) {
      return ApprovalPendingRegisterView(onReportSelected: onReportSelected);
    } else if (title.contains('Consignment Issue / Receipt Report')) {
      return ConsignmentIssueReceiptReportView(onReportSelected: onReportSelected);
    // ── G Account Receivable / Payable Reports ────────────────────────────────
    } else if (title.contains('Account & Bills Report')) {
      return AccountAndBillsReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Accounts Receivable Summary')) {
      return AccountsReceivableSummaryView(onReportSelected: onReportSelected);
    } else if (title.contains('Accounts Payable Summary')) {
      return AccountsPayableSummaryView(onReportSelected: onReportSelected);
    } else if (title.contains('Outstanding Aging Report')) {
      return OutstandingAgingReportView(onReportSelected: onReportSelected);
    // ── H Utility Reports ─────────────────────────────────────────────────────
    } else if (title.contains('Audit Trail Report')) {
      return AuditTrailReportView(onReportSelected: onReportSelected);
    } else if (title.contains('System Activity Log')) {
      return SystemActivityLogView(onReportSelected: onReportSelected);
    } else if (title.contains('Full Report')) {
      return const FullReportView();
    // F Fix Format sub-registers (ordered most-specific first)
    } else if (title.contains('Supplier Approval Challan Rate Fixing Register')) {
      return FixFormatRegisterView(registerTitle: 'Supplier Approval Challan Rate Fixing Register', onReportSelected: onReportSelected);
    } else if (title.contains('Supplier Approval Challan Register')) {
      return FixFormatRegisterView(registerTitle: 'Supplier Approval Challan Register', onReportSelected: onReportSelected);
    } else if (title.contains('Supplier Issue Register')) {
      return FixFormatRegisterView(registerTitle: 'Supplier Issue Register', onReportSelected: onReportSelected);
    } else if (title.contains('Supplier Receipt Register')) {
      return FixFormatRegisterView(registerTitle: 'Supplier Receipt Register', onReportSelected: onReportSelected);
    } else if (title.contains('Customer Issue Register')) {
      return FixFormatRegisterView(registerTitle: 'Customer Issue Register', onReportSelected: onReportSelected);
    } else if (title.contains('Customer Receipt Register')) {
      return FixFormatRegisterView(registerTitle: 'Customer Receipt Register', onReportSelected: onReportSelected);
    } else if (title.contains('Refinery Issue Register')) {
      return FixFormatRegisterView(registerTitle: 'Refinery Issue Register', onReportSelected: onReportSelected);
    } else if (title.contains('Refinery Receipt Register')) {
      return FixFormatRegisterView(registerTitle: 'Refinery Receipt Register', onReportSelected: onReportSelected);
    } else if (title.contains('Sales Return Register')) {
      return FixFormatRegisterView(registerTitle: 'Sales Return Register', onReportSelected: onReportSelected);
    } else if (title.contains('Purchase Return Register')) {
      return FixFormatRegisterView(registerTitle: 'Purchase Return Register', onReportSelected: onReportSelected);
    } else if (title.contains('Credit Note Register')) {
      return FixFormatRegisterView(registerTitle: 'Credit Note Register', onReportSelected: onReportSelected);
    } else if (title.contains('Debit Note Register')) {
      return FixFormatRegisterView(registerTitle: 'Debit Note Register', onReportSelected: onReportSelected);
    } else if (title.contains('Inward Service Register')) {
      return FixFormatRegisterView(registerTitle: 'Inward Service Register', onReportSelected: onReportSelected);
    } else if (title.contains('Outward Service Register')) {
      return FixFormatRegisterView(registerTitle: 'Outward Service Register', onReportSelected: onReportSelected);
    } else if (title.contains('Sales Register')) {
      return FixFormatRegisterView(registerTitle: 'Sales Register', onReportSelected: onReportSelected);
    } else if (title.contains('Purchase Register')) {
      return FixFormatRegisterView(registerTitle: 'Purchase Register', onReportSelected: onReportSelected);
    // G H I
    } else if (title.contains('Add/Less Split Transfer Label Report')) {
      return AddLessSplitTransferView(onReportSelected: onReportSelected);
    } else if (title.contains('Cash Receipt Exception Report')) {
      return CashReceiptExceptionView(onReportSelected: onReportSelected);
    } else if (title.contains('PAN Card Exception Report')) {
      return PanCardExceptionView(onReportSelected: onReportSelected);
    // ── F Supplier / Customer Reports ─────────────────────────────────────────
    } else if (title.contains('Supplier Outstanding Report')) {
      return SupplierOutstandingView(onReportSelected: onReportSelected);
    } else if (title.contains('Customer Outstanding Report')) {
      return CustomerOutstandingView(onReportSelected: onReportSelected);
    } else if (title.contains('Supplier Ledger Summary')) {
      return SupplierLedgerView(onReportSelected: onReportSelected);
    } else if (title.contains('Customer Ledger Summary')) {
      return CustomerLedgerView(onReportSelected: onReportSelected);
    // ── D Counter Reports ─────────────────────────────────────────────────────
    } else if (title.contains('Counter Sales Summary')) {
      return CounterSalesSummaryView(onReportSelected: onReportSelected);
    } else if (title.contains('Counter Stock Movement')) {
      return CounterStockMovementView(onReportSelected: onReportSelected);
    } else if (title.contains('Closing Stock Report')) {
      return ClosingStockReportView(
        items: _stockSummaryList,
        onRefresh: _loadReportData,
      );
    } else if (title.contains('Item Wise Stock Balance')) {
      return ItemWiseStockBalanceView(items: _itemWiseList);
    } else if (title.contains('Tag Wise Stock Report')) {
      return TagWiseStockReportView(items: _tagWiseList);
    } else if (title.contains('Counter Stock Report')) {
      return CounterStockReportView(items: _counterStockList);
    } else if (title.contains('Supplier Stock')) {
      return SupplierStockReportView(items: _supplierStockList);
    } else if (title.contains('Order Status Report')) {
      return OrderStatusReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Repairing Job Register')) {
      return RepairingJobRegisterView(onReportSelected: onReportSelected);
    } else if (title.contains('Custom User Report')) {
      return CustomUserReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Report Designer / Template Settings')) {
      return ReportDesignerSettingsView(onReportSelected: onReportSelected);
    // ── Category Header Fallbacks ──────────────────────────────────────────────
    } else if (title.contains('Account Reports')) {
      return LedgerAccountStatementView(onReportSelected: onReportSelected);
    } else if (title.contains('Daily Reports')) {
      return DailyActivityReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Stock Reports')) {
      return ClosingStockReportView(items: _stockSummaryList, onRefresh: _loadReportData);
    } else if (title.contains('Counter Reports')) {
      return CounterSalesSummaryView(onReportSelected: onReportSelected);
    } else if (title.contains('Approval / Consignment Reports')) {
      return ApprovalPendingRegisterView(onReportSelected: onReportSelected);
    } else if (title.contains('Supplier / Customer Reports')) {
      return SupplierOutstandingView(onReportSelected: onReportSelected);
    } else if (title.contains('Account Receivable / Payable Reports')) {
      return AccountAndBillsReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Utility Reports')) {
      return AuditTrailReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Order / Repairing Reports')) {
      return OrderStatusReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Custom Report')) {
      return CustomUserReportView(onReportSelected: onReportSelected);
    } else if (title.contains('Customize Reports')) {
      return ReportDesignerSettingsView(onReportSelected: onReportSelected);
    } else if (title.contains('Master Settings')) {
      return const FinancialYearView();
    } else if (title.contains('Fix Format Register') || title.contains('Register')) {
      return FixFormatRegisterView(registerTitle: title, onReportSelected: onReportSelected);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.brown.shade300),
          const SizedBox(height: 12),
          Text(
            '$title is currently empty.',
            style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStockReportPdf(String title, {required bool isPrintMode}) async {
    final fy = _selectedFinancialYear;
    final dr = '${DateFormat('dd-MMM-yyyy').format(_filterStartDate)} - ${DateFormat('dd-MMM-yyyy').format(_filterEndDate)}';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(isPrintMode ? 'Preparing $title for printing...' : 'Generating $title PDF...'),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final Uint8List pdfBytes;
      if (title.contains('Closing Stock Report')) {
        pdfBytes = await PdfStockReportApi.generateStockSummaryPdf(
          items: _stockSummaryList,
          financialYear: fy,
          dateRange: dr,
        );
      } else if (title.contains('Item Wise Stock Balance')) {
        pdfBytes = await PdfStockReportApi.generateItemWisePdf(
          items: _itemWiseList,
          financialYear: fy,
          dateRange: dr,
        );
      } else if (title.contains('Tag Wise Stock Report')) {
        pdfBytes = await PdfStockReportApi.generateTagWisePdf(
          items: _tagWiseList,
          financialYear: fy,
          dateRange: dr,
        );
      } else if (title.contains('Counter Stock Report')) {
        pdfBytes = await PdfStockReportApi.generateCounterStockPdf(
          items: _counterStockList,
          financialYear: fy,
          dateRange: dr,
        );
      } else {
        pdfBytes = await PdfStockReportApi.generateStockSummaryPdf(
          items: _stockSummaryList,
          financialYear: fy,
          dateRange: dr,
        );
      }

      await PdfStockReportApi.printPdf(pdfBytes, title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report PDF: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleStockReportExcel(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Text('$title successfully exported to Excel / CSV format!'),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.selectedReportTitle;
    final normalizedTitle = title.replaceFirst(RegExp(r'^[A-Z]\s+'), '').trim();

    if (normalizedTitle.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.analytics_outlined, size: 48, color: Colors.brown.shade300),
            const SizedBox(height: 12),
            const Text(
              'Please select a report from the menu to view details.',
              style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_isStockReport) {
      return _buildStockReportView(widget.selectedReportTitle);
    }

    // Only render the table view if the selected title is 'Account & Bills Report'
    if (normalizedTitle != 'Account & Bills Report') {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: Colors.brown.shade300),
            const SizedBox(height: 12),
            Text(
              '$normalizedTitle is currently empty / not implemented.',
              style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _billsStream,
      builder: (context, snapshot) {
        final Map<String, double> partyYtdCr = {};
        final Map<String, double> partyYtdDr = {};
        final List<Map<String, dynamic>> filteredRows = [];

        double totalReceivable = 0.0;
        double totalPayable = 0.0;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final bills = snapshot.data!.docs;

          // 1. Calculate YTD Cr and YTD Dr per party within the active financial year
          for (final doc in bills) {
            final data = doc.data() as Map<String, dynamic>;
            final vDate = _parseDocDate(data);
            if (vDate == null) continue;

            bool isInFinancialYear = true;
            if (_fromDate != null) {
              final fromMidnight = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
              if (vDate.isBefore(fromMidnight)) isInFinancialYear = false;
            }
            if (_toDate != null) {
              final toEnd = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59, 999);
              if (vDate.isAfter(toEnd)) isInFinancialYear = false;
            }

            if (isInFinancialYear) {
              final acName = data['acName']?.toString() ?? 'Walk-in Customer';
              final double voucherAmt = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;
              final double paymentAmt = (data['paymentAmt'] as num?)?.toDouble() ?? 0.0;

              // Use saved billType; fallback to voucherNo prefix for old records
              final String ytdBillType = data['billType']?.toString() ?? '';
              final String ytdVNo = (data['voucherNo']?.toString() ?? '').replaceAll('/', '-');
              final bool ytdIsPurchase = ytdBillType == 'Purchase' ||
                  (ytdBillType.isEmpty && (ytdVNo.startsWith('PR-') || ytdVNo.startsWith('SR-')));

              if (ytdIsPurchase) {
                partyYtdCr[acName] = (partyYtdCr[acName] ?? 0.0) + voucherAmt;
                partyYtdDr[acName] = (partyYtdDr[acName] ?? 0.0) + paymentAmt;
              } else {
                partyYtdDr[acName] = (partyYtdDr[acName] ?? 0.0) + voucherAmt;
                partyYtdCr[acName] = (partyYtdCr[acName] ?? 0.0) + paymentAmt;
              }
            }
          }

          // 2. Filter individual bills matching date filters and search
          final filterStartMidnight = DateTime(_filterStartDate.year, _filterStartDate.month, _filterStartDate.day);
          final filterEndDayEnd = DateTime(_filterEndDate.year, _filterEndDate.month, _filterEndDate.day, 23, 59, 59, 999);

          for (final doc in bills) {
            final data = doc.data() as Map<String, dynamic>;
            final vDate = _parseDocDate(data);
            if (vDate == null) continue;

            if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) {
              continue; // not in range
            }

            final voucherNo = (data['voucherNo']?.toString() ?? 'Unknown').replaceAll('/', '-');
            final acName = data['acName']?.toString() ?? 'Walk-in Customer';
            final salesman = data['salesman']?.toString() ?? 'N/A';
            final double voucherAmt = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;
            final double paymentAmt = (data['paymentAmt'] as num?)?.toDouble() ?? 0.0;
            double dueAmt = 0.0;
            if (data['dueAmt'] != null) {
              if (data['dueAmt'] is num) {
                dueAmt = (data['dueAmt'] as num).toDouble();
              } else {
                dueAmt = double.tryParse(data['dueAmt'].toString()) ?? 0.0;
              }
            }

            String categoryName = 'Customer';
            String groupHead = 'Sundry Debtors';
            String effectTo = 'Balance Sheet';

            // Use saved billType field; fallback to voucherNo prefix for old records
            final String billType = data['billType']?.toString() ?? '';
            final bool isPurchaseBill = billType == 'Purchase' ||
                (billType.isEmpty && (voucherNo.startsWith('PR-') || voucherNo.startsWith('SR-')));

            if (isPurchaseBill) {
              categoryName = 'Supplier';
              groupHead = 'Supplier For Goods';
              effectTo = 'Balance Sheet';
            } else if (acName.toUpperCase().contains('EXPENSE') || 
                acName.toUpperCase().contains('ADVERTISEMENT') || 
                acName.toUpperCase().contains('RENT') || 
                acName.toUpperCase().contains('SALARY')) {
              categoryName = 'Expense';
              groupHead = 'Indirect Expenses';
              effectTo = 'Profit And Loss Account';
            }

            // Read gstinNo and opBalance directly from Firestore — no fake generation
            final Map? customerDetails = data['customerDetails'] as Map?;
            final Map? supplierDetails = data['supplierDetails'] as Map?;
            final Map? partyDetails = customerDetails ?? supplierDetails;

            final String gstinNo =
                data['gstinNo']?.toString() ??
                data['gstNo']?.toString() ??
                data['gstin']?.toString() ??
                partyDetails?['gstin']?.toString() ??
                partyDetails?['gstNo']?.toString() ??
                partyDetails?['gstinNo']?.toString() ?? '';

            final double opBalanceVal =
                (data['opBalance'] as num?)?.toDouble() ??
                (data['openingBalance'] as num?)?.toDouble() ?? 0.0;
            final String opBalanceType =
                data['opBalanceType']?.toString() ?? 'Cr';

            // Apply search & UI dropdown filters
            final searchQuery = _searchCtrl.text.toLowerCase().trim();
            if (searchQuery.isNotEmpty && 
                !voucherNo.toLowerCase().contains(searchQuery) && 
                !acName.toLowerCase().contains(searchQuery) && 
                !gstinNo.toLowerCase().contains(searchQuery)) {
              continue;
            }
            if (_selectedCategoryFilter != 'All' && categoryName != _selectedCategoryFilter) {
              continue;
            }
            if (_selectedGroupFilter != 'All' && groupHead != _selectedGroupFilter) {
              continue;
            }
            if (_selectedEffectFilter != 'All' && effectTo != _selectedEffectFilter) {
              continue;
            }

            // Add to summary boxes totals
            if (categoryName == 'Customer') {
              if (dueAmt > 0) {
                totalReceivable += dueAmt;
              } else {
                totalPayable += dueAmt.abs();
              }
            } else if (categoryName == 'Supplier') {
              if (dueAmt > 0) {
                totalPayable += dueAmt;
              } else {
                totalReceivable += dueAmt.abs();
              }
            }

            final String itemName = data['itemName']?.toString() ??
                data['productName']?.toString() ??
                (data['items'] is List && (data['items'] as List).isNotEmpty
                    ? (data['items'][0]['name']?.toString() ??
                        data['items'][0]['productName']?.toString() ??
                        '')
                    : '');
            final String carat = data['carat']?.toString() ??
                data['purity']?.toString() ??
                data['metalId']?.toString() ??
                '';
            final double grossWeight =
                (data['grossWeight'] as num?)?.toDouble() ??
                    (data['grossWt'] as num?)?.toDouble() ??
                    0.0;
            final double netWeight =
                (data['netWeight'] as num?)?.toDouble() ??
                    (data['netWt'] as num?)?.toDouble() ??
                    0.0;
            final double gstTaxableAmt =
                (data['taxableAmount'] as num?)?.toDouble() ??
                    (data['subTotal'] as num?)?.toDouble() ??
                    voucherAmt;
            final double gstTotal =
                (data['gstTotal'] as num?)?.toDouble() ??
                    (data['totalGst'] as num?)?.toDouble() ??
                    3.0;
            final double totalGstAmount =
                (data['totalGstAmount'] as num?)?.toDouble() ??
                    (data['totalGst'] as num?)?.toDouble() ??
                    (data['taxAmount'] as num?)?.toDouble() ??
                    (gstTaxableAmt * (gstTotal / 100));
            final double igstAmt =
                (data['igstAmt'] as num?)?.toDouble() ??
                    (data['igstAmount'] as num?)?.toDouble() ??
                    0.0;
            final double cgstAmt =
                (data['cgstAmt'] as num?)?.toDouble() ??
                    (data['cgstAmount'] as num?)?.toDouble() ??
                    (igstAmt == 0 ? totalGstAmount / 2 : 0.0);
            final double sgstAmt =
                (data['sgstAmt'] as num?)?.toDouble() ??
                    (data['sgstAmount'] as num?)?.toDouble() ??
                    (igstAmt == 0 ? totalGstAmount / 2 : 0.0);
            final double rndDiscount =
                (data['discount'] as num?)?.toDouble() ??
                    (data['rndDiscount'] as num?)?.toDouble() ??
                    0.0;
            final double billAmount =
                (data['billAmount'] as num?)?.toDouble() ??
                    voucherAmt;
            final double cardAmt =
                (data['cardAmt'] as num?)?.toDouble() ??
                    (data['cardAmount'] as num?)?.toDouble() ??
                    0.0;
            final double bankAmt =
                (data['bankAmt'] as num?)?.toDouble() ??
                    (data['bankAmount'] as num?)?.toDouble() ??
                    0.0;
            final double cashAmt =
                (data['cashAmt'] as num?)?.toDouble() ??
                    (data['cashAmount'] as num?)?.toDouble() ??
                    (data['paymentAmt'] as num?)?.toDouble() ??
                    (billAmount - cardAmt - bankAmt);
            final String panNo =
                data['panNo']?.toString() ??
                data['panNumber']?.toString() ??
                data['pan']?.toString() ??
                partyDetails?['pan']?.toString() ??
                partyDetails?['panNo']?.toString() ??
                partyDetails?['panNumber']?.toString() ?? '';
            final String remark =
                data['remark']?.toString() ?? data['remarks']?.toString() ?? '';

            filteredRows.add({
              'voucherNo': voucherNo,
              'voucherDate': vDate,
              'acName': acName,
              'itemName': itemName,
              'carat': carat,
              'grossWeight': grossWeight,
              'netWeight': netWeight,
              'gstTaxableAmt': gstTaxableAmt,
              'gstTotal': gstTotal,
              'totalGstAmount': totalGstAmount,
              'igstAmt': igstAmt,
              'cgstAmt': cgstAmt,
              'sgstAmt': sgstAmt,
              'rndDiscount': rndDiscount,
              'billAmount': billAmount,
              'cardAmt': cardAmt,
              'bankAmt': bankAmt,
              'cashAmt': cashAmt,
              'panNo': panNo,
              'gstinNo': gstinNo,
              'remark': remark,
              'salesman': salesman,
              'categoryName': categoryName,
              'groupHead': groupHead,
              'effectTo': effectTo,
              'opBalanceVal': opBalanceVal,
              'opBalanceType': opBalanceType,
              'totCr': partyYtdCr[acName] ?? 0.0,
              'totDr': partyYtdDr[acName] ?? 0.0,
              'voucherAmt': voucherAmt,
              'paymentAmt': paymentAmt,
              'dueAmt': dueAmt,
              'docId': doc.id,
              'rawDoc': data,
            });
          }

          // Sort rows based on selected option
          if (_selectedSortOption == 'Date: Newest First') {
            filteredRows.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
          } else if (_selectedSortOption == 'Date: Oldest First') {
            filteredRows.sort((a, b) => (a['voucherDate'] as DateTime).compareTo(b['voucherDate'] as DateTime));
          } else if (_selectedSortOption == 'Voucher No: A-Z') {
            filteredRows.sort((a, b) => (a['voucherNo'] as String).compareTo(b['voucherNo'] as String));
          } else if (_selectedSortOption == 'Voucher No: Z-A') {
            filteredRows.sort((a, b) => (b['voucherNo'] as String).compareTo(a['voucherNo'] as String));
          } else if (_selectedSortOption == 'Party Name: A-Z') {
            filteredRows.sort((a, b) => (a['acName'] as String).compareTo(b['acName'] as String));
          } else if (_selectedSortOption == 'Party Name: Z-A') {
            filteredRows.sort((a, b) => (b['acName'] as String).compareTo(a['acName'] as String));
          } else if (_selectedSortOption == 'Bill Amount: High to Low') {
            filteredRows.sort((a, b) => (b['billAmount'] as double).compareTo(a['billAmount'] as double));
          } else if (_selectedSortOption == 'Bill Amount: Low to High') {
            filteredRows.sort((a, b) => (a['billAmount'] as double).compareTo(b['billAmount'] as double));
          } else if (_selectedSortOption == 'Due Amount: High to Low') {
            filteredRows.sort((a, b) => (b['dueAmt'] as double).compareTo(a['dueAmt'] as double));
          } else if (_selectedSortOption == 'Due Amount: Low to High') {
            filteredRows.sort((a, b) => (a['dueAmt'] as double).compareTo(b['dueAmt'] as double));
          }
        }

        // Table totals calculations over displayed rows
        double netOpBal = 0.0;
        double totalYtdCr = 0.0;
        double totalYtdDr = 0.0;
        double totalVoucherAmt = 0.0;
        double totalPaymentAmt = 0.0;
        double totalDueAmt = 0.0;

        double totalGrossWeight = 0.0;
        double totalNetWeight = 0.0;
        double totalGstTaxableAmt = 0.0;
        double totalGstTotal = 0.0;
        double totalTotalGstAmount = 0.0;
        double totalIgstAmt = 0.0;
        double totalCgstAmt = 0.0;
        double totalSgstAmt = 0.0;
        double totalRndDiscount = 0.0;
        double totalBillAmount = 0.0;
        double totalCardAmt = 0.0;
        double totalBankAmt = 0.0;
        double totalCashAmt = 0.0;

        for (final row in filteredRows) {
          double opVal = row['opBalanceVal'];
          if (row['opBalanceType'] == 'Dr') {
            netOpBal += opVal;
          } else {
            netOpBal -= opVal;
          }

          totalYtdCr += (row['totCr'] as double? ?? 0.0);
          totalYtdDr += (row['totDr'] as double? ?? 0.0);
          totalVoucherAmt += (row['voucherAmt'] as double? ?? 0.0);
          totalPaymentAmt += (row['paymentAmt'] as double? ?? 0.0);
          totalDueAmt += (row['dueAmt'] as double? ?? 0.0);

          totalGrossWeight += (row['grossWeight'] as double? ?? 0.0);
          totalNetWeight += (row['netWeight'] as double? ?? 0.0);
          totalGstTaxableAmt += (row['gstTaxableAmt'] as double? ?? 0.0);
          totalGstTotal += (row['gstTotal'] as double? ?? 0.0);
          totalTotalGstAmount += (row['totalGstAmount'] as double? ?? 0.0);
          totalIgstAmt += (row['igstAmt'] as double? ?? 0.0);
          totalCgstAmt += (row['cgstAmt'] as double? ?? 0.0);
          totalSgstAmt += (row['sgstAmt'] as double? ?? 0.0);
          totalRndDiscount += (row['rndDiscount'] as double? ?? 0.0);
          totalBillAmount += (row['billAmount'] as double? ?? 0.0);
          totalCardAmt += (row['cardAmt'] as double? ?? 0.0);
          totalBankAmt += (row['bankAmt'] as double? ?? 0.0);
          totalCashAmt += (row['cashAmt'] as double? ?? 0.0);
        }

        double absNetOpBal = netOpBal.abs();
        String netOpBalType = netOpBal >= 0 ? 'Dr' : 'Cr';

        return SelectionArea(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    MenuAnchor(
                      alignmentOffset: const Offset(0, 4),
                      style: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(const Color(0xFFFAF2E9)),
                        elevation: WidgetStateProperty.all(8),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFEBDCCB), width: 1.2),
                          ),
                        ),
                      ),
                      builder: (context, controller, child) => InkWell(
                        onTap: () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.selectedReportTitle,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF5D4037),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                size: 22,
                                color: Color(0xFF5D4037),
                              ),
                            ],
                          ),
                        ),
                      ),
                      menuChildren: buildReportMenuItems(kReportMenuItems, (title) {
                        widget.onReportSelected?.call(title);
                      }),
                    ),
                    Row(
                      children: [
                        // Year selector dropdown
                        _buildDropdownFilter<String>(
                          value: _yearsList.contains(_filterStartDate.year.toString()) ? _filterStartDate.year.toString() : _yearsList.first,
                          items: _yearsList,
                          onChanged: (val) {
                            if (val != null) {
                              final yearInt = int.parse(val);
                              setState(() {
                                int startMonth = _filterStartDate.month;
                                int startDay = _filterStartDate.day;
                                int endMonth = _filterEndDate.month;
                                int endDay = _filterEndDate.day;
                                
                                _filterStartDate = DateTime(yearInt, startMonth, math.min(startDay, DateTime(yearInt, startMonth + 1, 0).day));
                                _filterEndDate = DateTime(yearInt, endMonth, math.min(endDay, DateTime(yearInt, endMonth + 1, 0).day), 23, 59, 59, 999);
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        // Custom Date Range Picker button
                        OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                              initialDateRange: DateTimeRange(
                                start: _filterStartDate,
                                end: _filterEndDate,
                              ),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    scaffoldBackgroundColor: const Color(0xFFFDFBF7),
                                    dialogTheme: const DialogThemeData(
                                      backgroundColor: Color(0xFFFDFBF7),
                                    ),
                                    appBarTheme: const AppBarTheme(
                                      backgroundColor: _brown,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                    ),
                                    colorScheme: const ColorScheme.light(
                                      primary: _brown,
                                      onPrimary: Colors.white,
                                      surface: Color(0xFFFDFBF7),
                                      onSurface: _brown,
                                      secondary: _brownLight,
                                      onSecondary: Colors.white,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: _brown,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _filterStartDate = picked.start;
                                _filterEndDate = picked.end;
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5D4037),
                            side: const BorderSide(color: Color(0xFFE0D8C3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          icon: const Icon(Icons.calendar_today_rounded, size: 14),
                          label: Text(
                            '${DateFormat('dd/MM/yyyy').format(_filterStartDate)} - ${DateFormat('dd/MM/yyyy').format(_filterEndDate)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Export / Download Popup Button
                        PopupMenuButton<String>(
                          onSelected: _exportReport,
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'csv',
                              child: Row(
                                children: [
                                  Icon(Icons.insert_drive_file_outlined, size: 16, color: Colors.blue),
                                  SizedBox(width: 10),
                                  Text('Export to CSV (.csv)', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'xlsx',
                              child: Row(
                                children: [
                                  Icon(Icons.table_chart_outlined, size: 16, color: Colors.green),
                                  SizedBox(width: 10),
                                  Text('Export to Excel (.xlsx)', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pdf',
                              child: Row(
                                children: [
                                  Icon(Icons.picture_as_pdf_outlined, size: 16, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Export to PDF (.pdf)', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5D4037),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'Download',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Receivable, Payable, Difference boxes
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Receivable',
                        amount: totalReceivable,
                        subtitle: totalReceivable > 0
                            ? 'Outstanding from customers'
                            : 'No receivables outstanding.',
                        icon: Icons.arrow_downward_rounded,
                        iconColor: const Color(0xFF2E7D32),
                        iconBgColor: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Payable',
                        amount: totalPayable,
                        subtitle: totalPayable > 0
                            ? 'Outstanding to suppliers'
                            : 'No payables outstanding.',
                        icon: Icons.arrow_upward_rounded,
                        iconColor: const Color(0xFFC62828),
                        iconBgColor: const Color(0xFFFFEBEE),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Difference',
                        amount: (totalReceivable - totalPayable).abs(),
                        subtitle: totalReceivable >= totalPayable
                            ? 'Net Receivable'
                            : 'Net Payable',
                        icon: Icons.balance_rounded,
                        iconColor: const Color(0xFFE67E22),
                        iconBgColor: const Color(0xFFFDF2E9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Search Bar & Dropdowns
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0D8C3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Search',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 32,
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: (value) => setState(() {}),
                                style: const TextStyle(fontSize: 12),
                                decoration: InputDecoration(
                                  hintText: 'Search Voucher No, Account, or GSTIN...',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                                  prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF8D6E63)),
                                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFFE0D8C3)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Color(0xFF5D4037), width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFilterDropdownLabel(
                          label: 'Category',
                          value: _selectedCategoryFilter,
                          items: ['All', 'Customer', 'Supplier', 'Expense'],
                          onChanged: (val) => setState(() => _selectedCategoryFilter = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdownLabel(
                          label: 'Group Head',
                          value: _selectedGroupFilter,
                          items: ['All', 'Sundry Debtors', 'Supplier For Goods', 'Indirect Expenses'],
                          onChanged: (val) => setState(() => _selectedGroupFilter = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdownLabel(
                          label: 'Effect To',
                          value: _selectedEffectFilter,
                          items: ['All', 'Balance Sheet', 'Profit And Loss Account'],
                          onChanged: (val) => setState(() => _selectedEffectFilter = val!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFilterDropdownLabel(
                          label: 'Sort By',
                          value: _selectedSortOption,
                          items: [
                            'Date: Newest First',
                            'Date: Oldest First',
                            'Voucher No: A-Z',
                            'Voucher No: Z-A',
                            'Party Name: A-Z',
                            'Party Name: Z-A',
                            'Bill Amount: High to Low',
                            'Bill Amount: Low to High',
                            'Due Amount: High to Low',
                            'Due Amount: Low to High',
                          ],
                          onChanged: (val) => setState(() => _selectedSortOption = val!),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: filteredRows.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(48),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE0D8C3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text(
                              'No bills found for the selected filters.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF7F8C8D),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE0D8C3)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Scrollbar(
                              controller: _horizontalScrollCtrl,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: 3300, // Sum of 30 column widths (100+100+160+110+130+130+110+110+110+110+110+110+140+80+100+100+120+90+110+100+100+100+100+120+100+100+100+120+140+160)
                                  child: Column(
                                      children: [
                                        // Vertically scrollable Data Table
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.vertical,
                                            child: Table(
                                              columnWidths: const {
                                                0: FixedColumnWidth(100), // Voucher No
                                                1: FixedColumnWidth(100), // Vou Date
                                                2: FixedColumnWidth(160), // Account Name
                                                3: FixedColumnWidth(110), // Category Name
                                                4: FixedColumnWidth(130), // Group Head
                                                5: FixedColumnWidth(130), // Effect To
                                                6: FixedColumnWidth(110), // Op. Balance
                                                7: FixedColumnWidth(110), // Tot Cr. (YTD)
                                                8: FixedColumnWidth(110), // Tot Dr. (YTD)
                                                9: FixedColumnWidth(110), // Total Amt (₹)
                                                10: FixedColumnWidth(110), // Paid Amt (₹)
                                                11: FixedColumnWidth(110), // Due Amt (₹)
                                                12: FixedColumnWidth(140), // Item Name
                                                13: FixedColumnWidth(80),  // Carat
                                                14: FixedColumnWidth(100), // Gross Weight
                                                15: FixedColumnWidth(100), // Net Weight
                                                16: FixedColumnWidth(120), // GST Taxable Amount
                                                17: FixedColumnWidth(90),  // GST Total
                                                18: FixedColumnWidth(110), // Total GST Amount
                                                19: FixedColumnWidth(100), // IGST Amount
                                                20: FixedColumnWidth(100), // CGST Amt
                                                21: FixedColumnWidth(100), // SGST Amt
                                                22: FixedColumnWidth(100), // Rnd Discount
                                                23: FixedColumnWidth(120), // Bill Amount
                                                24: FixedColumnWidth(100), // Card Amt
                                                25: FixedColumnWidth(100), // Bank Amt
                                                26: FixedColumnWidth(100), // Cash Amt
                                                27: FixedColumnWidth(120), // PAN No
                                                28: FixedColumnWidth(140), // GST No
                                                29: FixedColumnWidth(160), // Remark
                                              },
                                            children: [
                                              TableRow(
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFFF9F6F0),
                                                  border: Border(
                                                    bottom: BorderSide(color: Color(0xFFE0D8C3), width: 1.5),
                                                  ),
                                                ),
                                                children: [
                                                  _buildTableHeaderCell('Voucher No'),
                                                  _buildTableHeaderCell('Vou Date'),
                                                  _buildTableHeaderCell('Account Name'),
                                                  _buildTableHeaderCell('Category Name'),
                                                  _buildTableHeaderCell('Group Head'),
                                                  _buildTableHeaderCell('Effect To'),
                                                  _buildTableHeaderCell('Op. Balance', alignRight: true),
                                                  _buildTableHeaderCell('Tot Cr. (YTD)', alignRight: true),
                                                  _buildTableHeaderCell('Tot Dr. (YTD)', alignRight: true),
                                                  _buildTableHeaderCell('Total Amt (₹)', alignRight: true),
                                                  _buildTableHeaderCell('Paid Amt (₹)', alignRight: true),
                                                  _buildTableHeaderCell('Due Amt (₹)', alignRight: true),
                                                  _buildTableHeaderCell('Item Name'),
                                                  _buildTableHeaderCell('Carat'),
                                                  _buildTableHeaderCell('Gross Weight', alignRight: true),
                                                  _buildTableHeaderCell('Net Weight', alignRight: true),
                                                  _buildTableHeaderCell('GST Taxable Amount', alignRight: true),
                                                  _buildTableHeaderCell('GST Total', alignRight: true),
                                                  _buildTableHeaderCell('Total GST Amount', alignRight: true),
                                                  _buildTableHeaderCell('IGST Amount', alignRight: true),
                                                  _buildTableHeaderCell('CGST Amt', alignRight: true),
                                                  _buildTableHeaderCell('SGST Amt', alignRight: true),
                                                  _buildTableHeaderCell('Rnd Discount', alignRight: true),
                                                  _buildTableHeaderCell('Bill Amount', alignRight: true),
                                                  _buildTableHeaderCell('Card Amt', alignRight: true),
                                                  _buildTableHeaderCell('Bank Amt', alignRight: true),
                                                  _buildTableHeaderCell('Cash Amt', alignRight: true),
                                                  _buildTableHeaderCell('PAN No'),
                                                  _buildTableHeaderCell('GST No'),
                                                  _buildTableHeaderCell('Remark'),
                                                ],
                                              ),
                                              ...filteredRows.map((row) {
                                                final double opVal = row['opBalanceVal'];
                                                final String opText = opVal > 0 
                                                    ? '${opVal.toStringAsFixed(2)} ${row['opBalanceType']}' 
                                                    : '0.00 Cr';
                                                    
                                                final DateTime vDate = row['voucherDate'];
                                                final String formattedDate = DateFormat('dd/MM/yyyy').format(vDate);

                                                void onDoubleTap() {
                                                   if (row['rawDoc'] != null) {
                                                     showDialog(
                                                       context: context,
                                                       builder: (context) => BillDetailDialog(docData: row['rawDoc']),
                                                     );
                                                   }
                                                 }

                                                return TableRow(
                                                  decoration: const BoxDecoration(
                                                    border: Border(
                                                      bottom: BorderSide(color: Color(0xFFF2ECE4)),
                                                    ),
                                                  ),
                                                  children: [
                                                    _buildTableCell(row['voucherNo'], isBold: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell(formattedDate, onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['acName'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['categoryName'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['groupHead'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['effectTo'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(opText, alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell((row['totCr'] as double).toStringAsFixed(2), alignRight: true, color: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                    _buildTableCell((row['totDr'] as double).toStringAsFixed(2), alignRight: true, color: const Color(0xFFC62828), onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['voucherAmt'] as double).toStringAsFixed(2)}', alignRight: true, color: const Color(0xFF2C3E50), onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['paymentAmt'] as double).toStringAsFixed(2)}', alignRight: true, color: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                    _buildTableCell(
                                                      '₹ ${(row['dueAmt'] as double).toStringAsFixed(2)}',
                                                      alignRight: true,
                                                      isBold: (row['dueAmt'] as double) > 0,
                                                      color: (row['dueAmt'] as double) > 0 ? const Color(0xFFC62828) : const Color(0xFF2C3E50),
                                                      onDoubleTap: onDoubleTap,
                                                    ),
                                                    _buildTableCell(row['itemName'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['carat'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell('${(row['grossWeight'] as double).toStringAsFixed(3)}g', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('${(row['netWeight'] as double).toStringAsFixed(3)}g', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['gstTaxableAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('${(row['gstTotal'] as double).toStringAsFixed(1)}%', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['totalGstAmount'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['igstAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['cgstAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['sgstAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['rndDiscount'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['billAmount'] as double).toStringAsFixed(2)}', alignRight: true, isBold: true, color: const Color(0xFF2C3E50), onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['cardAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['bankAmt'] as double).toStringAsFixed(2)}', alignRight: true, onDoubleTap: onDoubleTap),
                                                    _buildTableCell('₹ ${(row['cashAmt'] as double).toStringAsFixed(2)}', alignRight: true, color: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['panNo'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['gstinNo'], onDoubleTap: onDoubleTap),
                                                    _buildTableCell(row['remark'], onDoubleTap: onDoubleTap),
                                                  ],
                                                );
                                              }),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Pinned Sticky Bottom Totals Bar matching screenshot
                                      Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFDFBF7),
                                          border: Border(
                                            top: BorderSide(color: Color(0xFFE0D8C3), width: 2.0),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black12,
                                              blurRadius: 4,
                                              offset: Offset(0, -2),
                                            ),
                                          ],
                                        ),
                                        child: Table(
                                          columnWidths: const {
                                            0: FixedColumnWidth(100), // Voucher No
                                            1: FixedColumnWidth(100), // Vou Date
                                            2: FixedColumnWidth(160), // Account Name
                                            3: FixedColumnWidth(110), // Category Name
                                            4: FixedColumnWidth(130), // Group Head
                                            5: FixedColumnWidth(130), // Effect To
                                            6: FixedColumnWidth(110), // Op. Balance
                                            7: FixedColumnWidth(110), // Tot Cr. (YTD)
                                            8: FixedColumnWidth(110), // Tot Dr. (YTD)
                                            9: FixedColumnWidth(110), // Total Amt (₹)
                                            10: FixedColumnWidth(110), // Paid Amt (₹)
                                            11: FixedColumnWidth(110), // Due Amt (₹)
                                            12: FixedColumnWidth(140), // Item Name
                                            13: FixedColumnWidth(80),  // Carat
                                            14: FixedColumnWidth(100), // Gross Weight
                                            15: FixedColumnWidth(100), // Net Weight
                                            16: FixedColumnWidth(120), // GST Taxable Amount
                                            17: FixedColumnWidth(90),  // GST Total
                                            18: FixedColumnWidth(110), // Total GST Amount
                                            19: FixedColumnWidth(100), // IGST Amount
                                            20: FixedColumnWidth(100), // CGST Amt
                                            21: FixedColumnWidth(100), // SGST Amt
                                            22: FixedColumnWidth(100), // Rnd Discount
                                            23: FixedColumnWidth(120), // Bill Amount
                                            24: FixedColumnWidth(100), // Card Amt
                                            25: FixedColumnWidth(100), // Bank Amt
                                            26: FixedColumnWidth(100), // Cash Amt
                                            27: FixedColumnWidth(120), // PAN No
                                            28: FixedColumnWidth(140), // GST No
                                            29: FixedColumnWidth(120), // Remark
                                          },
                                          children: [
                                            TableRow(
                                              children: [
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTotalBoxCell(
                                                  text: '${absNetOpBal.toStringAsFixed(2)} $netOpBalType',
                                                  alignRight: true,
                                                ),
                                                _buildTotalBoxCell(
                                                  text: totalYtdCr.toStringAsFixed(2),
                                                  alignRight: true,
                                                ),
                                                _buildTotalBoxCell(
                                                  text: totalYtdDr.toStringAsFixed(2),
                                                  alignRight: true,
                                                ),
                                                _buildTotalBoxCell(
                                                  text: totalVoucherAmt.toStringAsFixed(2),
                                                  alignRight: true,
                                                ),
                                                _buildTotalBoxCell(
                                                  text: totalPaymentAmt.toStringAsFixed(2),
                                                  alignRight: true,
                                                ),
                                                _buildTotalBoxCell(
                                                  text: totalDueAmt.toStringAsFixed(2),
                                                  alignRight: true,
                                                  isBold: true,
                                                ),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTotalBoxCell(text: '${totalGrossWeight.toStringAsFixed(3)}g', alignRight: true),
                                                _buildTotalBoxCell(text: '${totalNetWeight.toStringAsFixed(3)}g', alignRight: true),
                                                _buildTotalBoxCell(text: totalGstTaxableAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalGstTotal.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalTotalGstAmount.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalIgstAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalCgstAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalSgstAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalRndDiscount.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalBillAmount.toStringAsFixed(2), alignRight: true, isBold: true),
                                                _buildTotalBoxCell(text: totalCardAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalBankAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTotalBoxCell(text: totalCashAmt.toStringAsFixed(2), alignRight: true),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                                _buildTableCell(''),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _exportReport(String format) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF5D4037)),
              SizedBox(width: 24),
              Text(
                'Compiling report data...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5D4037)),
              ),
            ],
          ),
        );
      },
    );
    
    // Simulate generation delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        
        final String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final String fileName = 'Report_$timestamp.$format';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('$fileName exported successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    });
  }

  Widget _buildFilterDropdownLabel({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
        ),
        const SizedBox(height: 4),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F6F0),
            border: Border.all(color: const Color(0xFFE0D8C3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF8D6E63)),
              style: const TextStyle(color: Color(0xFF5D4037), fontSize: 11, fontWeight: FontWeight.w600),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilter<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6F0),
        border: Border.all(color: const Color(0xFFE0D8C3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: Color(0xFF8D6E63)),
          style: const TextStyle(
            color: Color(0xFF5D4037),
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          onChanged: onChanged,
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return _HoverSummaryCardMaster(
      title: title,
      amount: amount,
      subtitle: subtitle,
      icon: icon,
      iconColor: iconColor,
      iconBgColor: iconBgColor,
      compact: true,
    );
  }

  Widget _buildTableHeaderCell(String text, {bool alignRight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5D4037),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool alignRight = false, Color? color, bool isBold = false, VoidCallback? onDoubleTap}) {
    Widget child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black87,
        ),
      ),
    );
    if (onDoubleTap != null) {
      return GestureDetector(
        onDoubleTap: onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      );
    }
    return child;
  }

  Widget _buildTotalBoxCell({
    required String text,
    bool alignRight = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFCCCCCC)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: const Color(0xFF2C3E50),
          ),
        ),
      ),
    );
  }
}

// ── Hover Summary Card for Master View ────────────────────────────────────────

class _HoverSummaryCardMaster extends StatefulWidget {
  final String title;
  final double amount;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool compact;

  const _HoverSummaryCardMaster({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.compact = false,
  });

  @override
  State<_HoverSummaryCardMaster> createState() => _HoverSummaryCardMasterState();
}

class _HoverSummaryCardMasterState extends State<_HoverSummaryCardMaster> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final double hPad = widget.compact ? 14 : 20;
    final double vPad = widget.compact ? 8 : 16;
    final double titleSize = widget.compact ? 11 : 12;
    final double amtSize = widget.compact ? 16 : 20;
    final double subtitleSize = widget.compact ? 10 : 11;
    final double iconSize = widget.compact ? 14 : 18;
    final double iconBoxSize = widget.compact ? 28 : 36;
    final String amtStr = widget.compact
        ? '₹ ${widget.amount.toStringAsFixed(2)}'
        : '₹ ${widget.amount.toStringAsFixed(0)}';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        transform: _isHovered
            ? (Matrix4.translationValues(0.0, -3.0, 0.0))
            : Matrix4.identity(),
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(widget.compact ? 8 : 10),
          border: Border.all(
            color: _isHovered ? const Color(0xFFCA6F1E) : const Color(0xFFE0D8C3),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            if (_isHovered)
              BoxShadow(
                color: const Color(0xFFCA6F1E).withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 6),
              )
            else
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      color: const Color(0xFF7F8C8D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: widget.compact ? 2 : 6),
                  Text(
                    amtStr,
                    style: TextStyle(
                      fontSize: amtSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  SizedBox(height: widget.compact ? 2 : 6),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: subtitleSize,
                      color: const Color(0xFF95A5A6),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: iconBoxSize,
              height: iconBoxSize,
              decoration: BoxDecoration(
                color: _isHovered
                    ? const Color(0xFFFDF6ED)
                    : widget.iconBgColor,
                border: Border.all(
                  color: _isHovered ? const Color(0xFFFBE8A6) : Colors.transparent,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: _isHovered ? const Color(0xFFCA6F1E) : widget.iconColor,
                size: iconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
