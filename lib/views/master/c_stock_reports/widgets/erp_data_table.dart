import 'package:flutter/material.dart';

class ErpTableColumn {
  final String title;
  final bool isNumeric;
  final String key;
  final double? width;

  const ErpTableColumn({
    required this.title,
    required this.key,
    this.isNumeric = false,
    this.width,
  });
}

class ErpDataTable extends StatefulWidget {
  final List<ErpTableColumn> columns;
  final List<Map<String, dynamic>> rows;
  final String? sortColumnKey;
  final bool isAscending;
  final ValueChanged<String>? onSort;
  final Map<String, dynamic>? footerTotals;
  final bool showPagination;

  const ErpDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnKey,
    this.isAscending = true,
    this.onSort,
    this.footerTotals,
    this.showPagination = true,
  });

  @override
  State<ErpDataTable> createState() => _ErpDataTableState();
}

class _ErpDataTableState extends State<ErpDataTable> {
  int _rowsPerPage = 10;
  int _currentPage = 0;
  int? _hoveredRowIndex;

  @override
  Widget build(BuildContext context) {
    final totalRows = widget.rows.length;
    final totalPages = (totalRows / _rowsPerPage).ceil().clamp(1, 9999);
    final startIndex = _currentPage * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage).clamp(0, totalRows);
    final currentPageRows = widget.showPagination
        ? ((startIndex < totalRows) ? widget.rows.sublist(startIndex, endIndex) : <Map<String, dynamic>>[])
        : widget.rows;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DDD0), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E2723).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Body with Sticky Header
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double minWidth = widget.columns.length * 130.0;
                final double tableWidth = mathMax(constraints.maxWidth, mathMax(1000, minWidth));
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        // Sticky Header Row
                        Container(
                          height: 58,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3E2723),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
                          ),
                          child: Row(
                            children: widget.columns.map((col) {
                              final isSorted = widget.sortColumnKey == col.key;
                              return Expanded(
                                flex: col.width != null ? (col.width! ~/ 10) : 10,
                                child: InkWell(
                                  onTap: widget.onSort != null ? () => widget.onSort!(col.key) : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    alignment:
                                        col.isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Row(
                                      mainAxisAlignment: col.isNumeric
                                          ? MainAxisAlignment.end
                                          : MainAxisAlignment.start,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            col.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              letterSpacing: 0.3,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isSorted) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            widget.isAscending
                                                ? Icons.arrow_upward_rounded
                                                : Icons.arrow_downward_rounded,
                                            size: 14,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Data Rows
                        Expanded(
                          child: currentPageRows.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No matching records found',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8D6E63),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: currentPageRows.length,
                                  itemBuilder: (context, index) {
                                    final row = currentPageRows[index];
                                    final isAlternate = index % 2 == 1;
                                    final isHovered = _hoveredRowIndex == index;

                                    Color rowBgColor = isAlternate
                                        ? const Color(0xFFFAF6F0)
                                        : Colors.white;

                                    if (isHovered) {
                                      rowBgColor = const Color(0xFFFFF7ED);
                                    }

                                    return MouseRegion(
                                      onEnter: (_) => setState(() => _hoveredRowIndex = index),
                                      onExit: (_) => setState(() => _hoveredRowIndex = null),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          color: rowBgColor,
                                          border: const Border(
                                            bottom: BorderSide(color: Color(0xFFF3ECE1), width: 1),
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Row(
                                          children: widget.columns.map((col) {
                                            final val = row[col.key];
                                            String displayVal = val?.toString() ?? '-';
                                            Color textColor = const Color(0xFF2C3E50);
                                            FontWeight fontWeight = FontWeight.normal;

                                            // Apply Green/Red rules for Stock In / Out & Available / Sold
                                            if (col.key == 'stockIn' || displayVal == 'Available') {
                                              textColor = const Color(0xFF15803D);
                                              fontWeight = FontWeight.bold;
                                            } else if (col.key == 'stockOut' || displayVal == 'Sold') {
                                              textColor = const Color(0xFFB91C1C);
                                              fontWeight = FontWeight.bold;
                                            } else if (displayVal == 'Reserved') {
                                              textColor = const Color(0xFFB45309);
                                              fontWeight = FontWeight.bold;
                                            } else if (col.key == 'value' || col.key == 'closingQty') {
                                              fontWeight = FontWeight.w600;
                                            }

                                            return Expanded(
                                              flex: col.width != null ? (col.width! ~/ 10) : 10,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                                alignment: col.isNumeric
                                                    ? Alignment.centerRight
                                                    : Alignment.centerLeft,
                                                child: Text(
                                                  displayVal,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: fontWeight,
                                                    color: textColor,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // Footer Totals Row (Optional)
                        if (widget.footerTotals != null)
                          Container(
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4A342E),
                              border: Border(top: BorderSide(color: Color(0xFF3E2723), width: 1.5)),
                            ),
                            child: Row(
                              children: widget.columns.map((col) {
                                final totalVal = widget.footerTotals![col.key]?.toString() ?? '';
                                return Expanded(
                                  flex: col.width != null ? (col.width! ~/ 10) : 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    alignment:
                                        col.isNumeric ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Text(
                                      totalVal,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFFEF3C7),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Pagination Controls
          if (widget.showPagination)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFCFAF5),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
                border: Border(top: BorderSide(color: Color(0xFFE5DDD0), width: 1)),
              ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Rows per page dropdown
                Row(
                  children: [
                    const Text(
                      'Rows per page:',
                      style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE5DDD0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _rowsPerPage,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _rowsPerPage = val;
                                _currentPage = 0;
                              });
                            }
                          },
                          items: [5, 10, 20, 50].map((n) {
                            return DropdownMenuItem<int>(
                              value: n,
                              child: Text('$n'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Showing ${totalRows == 0 ? 0 : startIndex + 1} - $endIndex of $totalRows entries',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

                // Page Navigation
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      color: const Color(0xFF3E2723),
                      onPressed: _currentPage > 0
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text(
                      'Page ${_currentPage + 1} of $totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      color: const Color(0xFF3E2723),
                      onPressed: (_currentPage + 1) < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double mathMax(double a, double b) => a > b ? a : b;
}
