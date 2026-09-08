import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../report_shared.dart';

class ReportHeader extends StatefulWidget {
  final String title;
  final String selectedFinancialYear;
  final ValueChanged<String> onFinancialYearChanged;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTimeRange> onDateRangeChanged;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onPrint;
  final ValueChanged<String>? onReportSelected;

  const ReportHeader({
    super.key,
    required this.title,
    required this.selectedFinancialYear,
    required this.onFinancialYearChanged,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onPrint,
    this.onReportSelected,
  });

  @override
  State<ReportHeader> createState() => _ReportHeaderState();
}

class _ReportHeaderState extends State<ReportHeader> {
  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: widget.startDate, end: widget.endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF3E2723),
              onPrimary: Colors.white,
              surface: Color(0xFFFCFAF5),
              onSurface: Color(0xFF3E2723),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      widget.onDateRangeChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final dateRangeStr =
        '${dateFormat.format(widget.startDate)} - ${dateFormat.format(widget.endDate)}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 950;

        final titleWidget = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.assessment_rounded,
              color: Color(0xFF8D6E63),
              size: 16,
            ),
            const SizedBox(width: 8),
            buildTitleDropdown(
              context: context,
              currentTitle: widget.title,
              onSelected: (newTitle) {
                widget.onReportSelected?.call(newTitle);
              },
              textColor: const Color(0xFF3E2723),
              fontSize: 14,
              bold: true,
            ),
          ],
        );

        final controlsWidget = Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            // Date Range Picker Button
            InkWell(
              onTap: () => _pickDateRange(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5DDD0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.date_range_rounded, size: 13, color: Color(0xFFB45309)),
                    const SizedBox(width: 6),
                    Text(
                      dateRangeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3E2723),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Export Dropdown Menu Button (PDF / Excel)
            Theme(
              data: Theme.of(context).copyWith(cardColor: const Color(0xFFFAF2E9)),
              child: MenuAnchor(
                builder: (context, controller, child) {
                  return OutlinedButton.icon(
                    onPressed: () {
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF3E2723),
                      side: const BorderSide(color: Color(0xFFE5DDD0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 14, color: Color(0xFF3E2723)),
                    label: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_drop_down_rounded, size: 14),
                      ],
                    ),
                  );
                },
                menuChildren: [
                  MenuItemButton(
                    onPressed: widget.onExportPdf,
                    child: const Row(
                      children: [
                        Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                        SizedBox(width: 10),
                        Text('Export as PDF', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                  MenuItemButton(
                    onPressed: widget.onExportExcel,
                    child: const Row(
                      children: [
                        Icon(Icons.table_chart_rounded, color: Colors.green, size: 18),
                        SizedBox(width: 10),
                        Text('Export as Excel (CSV)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Direct Print Button
            ElevatedButton.icon(
              onPressed: widget.onPrint,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 32),
                backgroundColor: const Color(0xFF3E2723),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.print_rounded, size: 14),
              label: const Text(
                'Print',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
          ],
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Color(0xFFE5DDD0), width: 1),
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 12),
                    controlsWidget,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    titleWidget,
                    controlsWidget,
                  ],
                ),
        );
      },
    );
  }
}
