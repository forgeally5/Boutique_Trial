// report_shared.dart
// Shared report menu items and helpers for master report views.

import 'package:flutter/material.dart';

final List<Map<String, dynamic>> kReportMenuItems = [
  {
    'title': 'A Daily Reports',
    'children': [
      {'title': 'A Daily Activity Report'},
      {'title': 'B Daily Statement'},
      {'title': 'C Item Wise Report'},
      {'title': 'D Monthly Summary Report'},
      {'title': 'E Voucher Print'},
      {
        'title': 'F Fix Format Register',
        'children': [
          {'title': 'A Sales Register'},
          {'title': 'B Purchase Register'},
          {'title': 'C Supplier Issue Register'},
          {'title': 'D Supplier Receipt Register'},
          {'title': 'E Customer Issue Register'},
          {'title': 'F Customer Receipt Register'},
          {'title': 'G Refinery Issue Register'},
          {'title': 'H Refinery Receipt Register'},
          {'title': 'I Sales Return Register'},
          {'title': 'J Purchase Return Register'},
          {'title': 'K Supplier Approval Challan Register'},
          {'title': 'L Supplier Approval Challan Rate Fixing Register'},
          {'title': 'M Credit Note Register'},
          {'title': 'N Debit Note Register'},
          {'title': 'O Inward Service Register'},
          {'title': 'P Outward Service Register'},
        ]
      },
      {'title': 'G Add/Less Split Transfer Label Report'},
      {'title': 'H Cash Receipt Exception Report'},
      {'title': 'I PAN Card Exception Report'},
    ]
  },
  {
    'title': 'B Account Reports',
    'children': [
      {'title': 'A Ledger / Account Statement'},
      {'title': 'B Day Book Report'},
      {'title': 'C Cash / Bank Book Report'},
      {'title': 'D Trial Balance Report'},
      {'title': 'E Profit & Loss Account'},
      {'title': 'F Balance Sheet Report'},
      {'title': 'G Group Summary Report'},
      {'title': 'H Amount Details'},
      {
        'title': 'I GST Report',
        'children': [
          {'title': 'A GST Exception Report'},
          {'title': 'B GST Summary Report'},
          {'title': 'C GST Ratewise Summary Report'},
          {'title': 'D GST Advance Receipt Report'},
          {'title': 'E GST Reverse Charge Report'},
          {'title': 'F Pending Approval Report (GST)'},
          {'title': 'G Pending Supplier O/s. Report (GST)'},
          {
            'title': 'H GST Return',
            'children': [
              {'title': 'A GSTR-1 Report'},
              {'title': 'B GSTR-3B Report'},
              {'title': 'C GSTR-9 Annual Report'},
            ]
          },
        ]
      },
    ]
  },
  {
    'title': 'C Stock Reports',
    'children': [
      {'title': 'A Closing Stock Report'},
      {'title': 'B Item Wise Stock Balance'},
      {'title': 'C Tag Wise Stock Report'},
      {'title': 'D Counter Stock Report'},
      {'title': 'E Supplier Stock'},
    ]
  },
  {
    'title': 'D Counter Reports',
    'children': [
      {'title': 'A Counter Sales Summary'},
      {'title': 'B Counter Stock Movement'},
    ]
  },
  {
    'title': 'E Approval / Consignment Reports',
    'children': [
      {'title': 'A Approval Pending Register'},
      {'title': 'B Consignment Issue / Receipt Report'},
    ]
  },
  {
    'title': 'F Supplier / Customer Reports',
    'children': [
      {'title': 'A Supplier Outstanding Report'},
      {'title': 'B Customer Outstanding Report'},
      {'title': 'C Supplier Ledger Summary'},
      {'title': 'D Customer Ledger Summary'},
    ]
  },
  {
    'title': 'G Account Receivable / Payable Reports',
    'children': [
      {'title': 'A Account & Bills Report'},
      {'title': 'B Accounts Receivable Summary'},
      {'title': 'C Accounts Payable Summary'},
      {'title': 'D Outstanding Aging Report'},
    ]
  },
  {
    'title': 'H Utility Reports',
    'children': [
      {'title': 'A Audit Trail Report'},
      {'title': 'B System Activity Log'},
    ]
  },
  {
    'title': 'I Order / Repairing Reports',
    'children': [
      {'title': 'A Order Status Report'},
      {'title': 'B Repairing Job Register'},
    ]
  },
  {
    'title': 'J Custom Report',
    'children': [
      {'title': 'A Custom User Report'},
    ]
  },
  {
    'title': 'K Customize Reports',
    'children': [
      {'title': 'A Report Designer / Template Settings'},
    ]
  },
  {
    'title': 'L Full Report',
    'children': []
  },
  {
    'title': 'M Master Settings',
    'children': [
      {'title': 'A Financial Year Settings'},
    ]
  },
];

String normalizeTitle(String t) {
  var clean = t.replaceAll(RegExp(r'\(.*?\)'), '');
  clean = clean.replaceAll(RegExp(r'\s+'), ' ');
  clean = clean.replaceFirst(RegExp(r'^[A-Z]\s+'), '');
  return clean.trim().toLowerCase();
}

List<Map<String, dynamic>>? findSiblings(List<Map<String, dynamic>> items, String targetTitle) {
  final normTarget = normalizeTitle(targetTitle);
  for (final item in items) {
    final normItem = normalizeTitle(item['title'] as String);
    if (normItem == normTarget) {
      return items;
    }
    final children = item['children'] as List?;
    if (children != null) {
      final found = findSiblings(children.cast<Map<String, dynamic>>(), targetTitle);
      if (found != null) return found;
    }
  }
  return null;
}

List<String> getSiblingTitles(String currentTitle) {
  final norm = normalizeTitle(currentTitle);

  // If viewing any GST report, return the complete GST reports suite in exact order
  if (norm.contains('gst') || norm.contains('gstr')) {
    return [
      'A GST Exception Report',
      'B GST Summary Report',
      'C GST Ratewise Summary Report',
      'D GST Advance Receipt Report',
      'E GST Reverse Charge Report',
      'F Pending Approval Report (GST)',
      'G Pending Supplier O/s. Report (GST)',
      'H GST Return',
    ];
  }

  final siblings = findSiblings(kReportMenuItems, currentTitle);
  if (siblings == null) return [currentTitle];
  return siblings
      .map((e) => e['title'] as String)
      .toList();
}

Widget buildTitleDropdown({
  required BuildContext context,
  required String currentTitle,
  required ValueChanged<String> onSelected,
  Color textColor = const Color(0xFF3E2723),
  double fontSize = 14,
  bool bold = true,
  bool isSerif = false,
}) {
  final siblings = getSiblingTitles(currentTitle);
  if (siblings.length <= 1) {
    return Text(
      currentTitle.replaceFirst(RegExp(r'^[A-Z]\s+'), ''),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: textColor,
        fontFamily: isSerif ? 'serif' : null,
      ),
    );
  }

  // Find exact value from siblings matching current title
  final selectedValue = siblings.firstWhere(
    (t) => normalizeTitle(t) == normalizeTitle(currentTitle),
    orElse: () => siblings.first,
  );

  return MouseRegion(
    cursor: SystemMouseCursors.click,
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedValue,
        isDense: true,
        dropdownColor: const Color(0xFFFFFDFB),
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: fontSize + 4),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: textColor,
          fontFamily: isSerif ? 'serif' : null,
        ),
        selectedItemBuilder: (c) => siblings.map((t) => Container(
          alignment: Alignment.centerLeft,
          child: Text(
            t.replaceFirst(RegExp(r'^[A-Z]\s+'), ''),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: textColor,
              fontFamily: isSerif ? 'serif' : null,
            ),
          ),
        )).toList(),
        items: siblings.map((t) => DropdownMenuItem<String>(
          value: t,
          child: Text(
            t, // Show full prefix + name in dropdown items
            style: TextStyle(
              fontSize: fontSize - 2,
              fontWeight: normalizeTitle(t) == normalizeTitle(currentTitle) ? FontWeight.bold : FontWeight.normal,
              color: const Color(0xFF5D4037),
            ),
          ),
        )).toList(),
        onChanged: (val) {
          if (val != null) {
            onSelected(val);
          }
        },
      ),
    ),
  );
}
