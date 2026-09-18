import 'package:flutter/material.dart';
import '../../utils/boutique_theme.dart';
import 'customer_return_tab.dart';
import 'vendor_issue_tab.dart';

class IssueReportScreen extends StatelessWidget {
  const IssueReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Container(
        color: BoutiqueColors.bgMain,
        child: Column(
          children: [
            Container(
              color: BoutiqueColors.bgCard,
              child: const TabBar(
                labelColor: BoutiqueColors.accent,
                unselectedLabelColor: BoutiqueColors.textSecondary,
                indicatorColor: BoutiqueColors.accent,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Customer Returns'),
                  Tab(text: 'Vendor / Purchase Issues'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  CustomerReturnTab(),
                  VendorIssueTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
