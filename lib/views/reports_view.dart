import 'package:flutter/material.dart';
import '../utils/boutique_theme.dart';
import 'reports/issue_report_screen.dart';
import 'reports/stock_report_screen.dart';
import 'reports/sales_report_screen.dart';

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top Header ────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: BoutiqueColors.bgCard,
            border:
                Border(bottom: BorderSide(color: BoutiqueColors.border, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.only(left: 28, right: 28, top: 20, bottom: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: BoutiqueColors.accentSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.analytics_outlined,
                          color: BoutiqueColors.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: BoutiqueColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Issue Returns • Stock Overview • Sales Analytics',
                          style: TextStyle(
                              fontSize: 12,
                              color: BoutiqueColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tab Bar
              TabBar(
                controller: _tabController,
                isScrollable: false,
                labelColor: BoutiqueColors.accent,
                unselectedLabelColor: BoutiqueColors.textSecondary,
                indicatorColor: BoutiqueColors.accent,
                indicatorWeight: 2.5,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 0),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontSize: 13),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_return_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Issue Report'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Stock Report'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bar_chart_rounded, size: 16),
                        SizedBox(width: 8),
                        Text('Sales Report'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Tab Body ──────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              IssueReportScreen(),
              StockReportScreen(),
              SalesReportScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
