import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../dialogs/bill_detail_dialog.dart';

// ── Shared constants ──────────────────────────────────────────────────────────
const _br      = Color(0xFF3E2723);
const _bdr     = Color(0xFFE5DDD0);
const _bg0     = Color(0xFFFDFBF7);
const _bg1     = Color(0xFFF9F6F0);

// ── Shared helpers ─────────────────────────────────────────────────────────────
String _fmt(double v) => NumberFormat('#,##,##0.00', 'en_IN').format(v);
double _fdbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

// Shared date-range picker (reusable)
Future<DateTimeRange?> _pickRange(BuildContext ctx, DateTimeRange current) =>
    showDateRangePicker(
      context: ctx,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: current,
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _br,
            onPrimary: Colors.white,
            surface: _bg0,
            onSurface: _br,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
        ),
        child: child!,
      ),
    );

// Loading state
const Widget _loader = Center(child: CircularProgressIndicator(color: _br));

// Empty state
Widget _emptyState(String msg) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 44, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(msg, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ],
      ),
    );

// ─── Table helpers ─────────────────────────────────────────────────────────────
Widget _th(String t, {double? w, bool r = false, bool flex = false}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Text(t,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63))),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _td(String t, {double? w, bool r = false, bool flex = false, bool bold = false, Color? c, VoidCallback? onDoubleTap}) {
  Widget inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: r ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(t,
          style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: c ?? Colors.black87)),
    ),
  );
  if (onDoubleTap != null) {
    inner = GestureDetector(
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: inner,
    );
  }
  return flex ? Expanded(child: inner) : inner;
}

Widget _tt(String t, {double? w, bool r = false, bool flex = false, bool bold = true, Color? c}) {
  final inner = Container(
    width: flex ? null : w,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
    child: Text(t,
        textAlign: r ? TextAlign.right : TextAlign.left,
        style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: c ?? _br)),
  );
  return flex ? Expanded(child: inner) : inner;
}

Widget _ttBox(String t, {required double w, bool r = false, bool bold = false, Color? c}) {
  if (t.isEmpty) {
    return SizedBox(width: w);
  }
  return Container(
    width: w,
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: r ? Alignment.centerRight : Alignment.centerLeft,
        child: Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: c ?? const Color(0xFF2C3E50),
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  FULL REPORT VIEW
// ─────────────────────────────────────────────────────────────────────────────
class FullReportView extends StatefulWidget {
  const FullReportView({super.key});
  @override State<FullReportView> createState() => _FullReportViewState();
}

class _FullReportViewState extends State<FullReportView> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to   = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59, 999);

  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  String _selectedCategoryFilter = 'All';
  String _selectedGroupFilter = 'All';
  String _selectedEffectFilter = 'All';
  String _selectedSortOption = 'Date: Newest First';

  final _horizontalScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _horizontalScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final billsSnap = await FirebaseFirestore.instance.collection('bills').get();
      final cashSnap = await FirebaseFirestore.instance.collection('cash_entries').get();
      final bankSnap = await FirebaseFirestore.instance.collection('bank_entries').get();
      final journalSnap = await FirebaseFirestore.instance.collection('journal_entries').get();
      final receiptSnap = await FirebaseFirestore.instance.collection('cash_bank_card_receipt_entries').get();
      final serviceSnap = await FirebaseFirestore.instance.collection('service_entries').get();
      final alterationSnap = await FirebaseFirestore.instance.collection('alteration_entries').get();
      final challanSnap = await FirebaseFirestore.instance.collection('delivery_challans').get();

      final bills = billsSnap.docs;
      final Map<String, double> partyYtdCr = {};
      final Map<String, double> partyYtdDr = {};

      for (final doc in bills) {
        final data = doc.data();
        final vDate = _parseDocDate(data);
        if (vDate == null) continue;

        final fromMidnight = DateTime(_from.year, _from.month, _from.day);
        final toEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

        if (vDate.isAfter(fromMidnight.subtract(const Duration(days: 1))) && 
            vDate.isBefore(toEnd.add(const Duration(days: 1)))) {
          final acName = data['acName']?.toString() ?? 'Walk-in Customer';
          final double voucherAmt = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;
          final double paymentAmt = (data['paymentAmt'] as num?)?.toDouble() ?? 0.0;

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

      final List<Map<String, dynamic>> list = [];
      final filterStartMidnight = DateTime(_from.year, _from.month, _from.day);
      final filterEndDayEnd = DateTime(_to.year, _to.month, _to.day, 23, 59, 59, 999);

      // ── Process collection: bills ──────────────────────────────────────────
      for (final doc in bills) {
        final data = doc.data();
        final vDate = _parseDocDate(data);
        if (vDate == null) continue;

        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) {
          continue;
        }

        final voucherNo = (data['voucherNo']?.toString() ?? 'Unknown').replaceAll('/', '-');
        final acName = data['acName']?.toString() ?? 'Walk-in Customer';
        final salesman = data['salesman']?.toString() ?? 'N/A';
        final double voucherAmt = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;
        final double paymentAmt = (data['paymentAmt'] as num?)?.toDouble() ?? 0.0;
        final double dueAmt = (data['dueAmt'] as num?)?.toDouble() ?? 0.0;

        String categoryName = 'Customer';
        String groupHead = 'Sundry Debtors';
        String effectTo = 'Balance Sheet';

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

        list.add({
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

      // ── Process collection: cash_entries ───────────────────────────────────
      for (final doc in cashSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['voucherNo']?.toString() ?? 'CS-${doc.id.substring(0, 4)}';
        final acName = d['accountName']?.toString() ?? d['acName']?.toString() ?? 'Cash Account';
        final double amount = _fdbl(d['amount'] ?? d['totalAmount']);
        final isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': 'Cash Transaction',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': amount,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': amount,
          'cardAmt': 0.0,
          'bankAmt': 0.0,
          'cashAmt': amount,
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? d['reference']?.toString() ?? '',
          'salesman': '—',
          'categoryName': isPayment ? 'Supplier' : 'Customer',
          'groupHead': isPayment ? 'Indirect Expenses' : 'Cash Received',
          'effectTo': 'Profit And Loss Account',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Cr',
          'totCr': isPayment ? 0.0 : amount,
          'totDr': isPayment ? amount : 0.0,
          'voucherAmt': isPayment ? 0.0 : amount,
          'paymentAmt': isPayment ? amount : 0.0,
          'dueAmt': 0.0,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: bank_entries ───────────────────────────────────
      for (final doc in bankSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['voucherNo']?.toString() ?? 'BK-${doc.id.substring(0, 4)}';
        final acName = d['accountName']?.toString() ?? d['acName']?.toString() ?? 'Bank Account';
        final double amount = _fdbl(d['amount']);
        final isPayment = d['voucherType']?.toString().toLowerCase().contains('payment') ?? false;

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': 'Bank Transaction (${d['bookName'] ?? 'Bank'})',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': amount,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': amount,
          'cardAmt': 0.0,
          'bankAmt': amount,
          'cashAmt': 0.0,
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? '',
          'salesman': '—',
          'categoryName': isPayment ? 'Supplier' : 'Customer',
          'groupHead': isPayment ? 'Bank Paid' : 'Bank Received',
          'effectTo': 'Profit And Loss Account',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Cr',
          'totCr': isPayment ? 0.0 : amount,
          'totDr': isPayment ? amount : 0.0,
          'voucherAmt': isPayment ? 0.0 : amount,
          'paymentAmt': isPayment ? amount : 0.0,
          'dueAmt': 0.0,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: journal_entries ────────────────────────────────
      for (final doc in journalSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['voucherNo']?.toString() ?? 'JR-${doc.id.substring(0, 4)}';
        final acName = d['accountName']?.toString() ?? d['acName']?.toString() ?? 'Journal Account';
        final double amount = _fdbl(d['amount']);

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': 'Journal Adjustment',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': amount,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': amount,
          'cardAmt': 0.0,
          'bankAmt': 0.0,
          'cashAmt': 0.0,
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? '',
          'salesman': '—',
          'categoryName': 'Journal',
          'groupHead': 'Indirect Expenses',
          'effectTo': 'Profit And Loss Account',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Cr',
          'totCr': amount,
          'totDr': amount,
          'voucherAmt': amount,
          'paymentAmt': amount,
          'dueAmt': 0.0,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: cash_bank_card_receipt_entries ─────────────────
      for (final doc in receiptSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['receiptNo']?.toString() ?? d['voucherNo']?.toString() ?? 'RC-${doc.id.substring(0, 4)}';
        final acName = d['customerName']?.toString() ?? d['acName']?.toString() ?? 'Customer';
        double cash = 0.0;
        double bank = 0.0;
        double card = 0.0;

        if (d['rows'] is List && (d['rows'] as List).isNotEmpty) {
          for (final row in (d['rows'] as List)) {
            final double amt = _fdbl(row['amount']);
            final String mode = (row['mode'] ?? 'Cash').toString().toLowerCase();
            if (mode == 'cash') {
              cash += amt;
            } else if (mode == 'card') {
              card += amt;
            } else {
              bank += amt;
            }
          }
        } else {
          cash = _fdbl(d['cashAmt'] ?? d['cashAmount']);
          bank = _fdbl(d['bankAmt'] ?? d['bankAmount']);
          card = _fdbl(d['cardAmt'] ?? d['cardAmount']);
        }
        final double total = cash + bank + card;

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': 'Receipt Payment Mode Entry',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': total,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': total,
          'cardAmt': card,
          'bankAmt': bank,
          'cashAmt': cash,
          'panNo': d['panNo']?.toString() ?? '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? d['remarks']?.toString() ?? '',
          'salesman': d['salesman']?.toString() ?? '—',
          'categoryName': 'Customer',
          'groupHead': 'Sundry Debtors',
          'effectTo': 'Balance Sheet',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Dr',
          'totCr': total,
          'totDr': 0.0,
          'voucherAmt': 0.0,
          'paymentAmt': total,
          'dueAmt': 0.0,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: service_entries ────────────────────────────────
      for (final doc in serviceSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['voucherNo']?.toString() ?? 'SRV-${doc.id.substring(0, 4)}';
        final acName = d['customerName']?.toString() ?? d['acName']?.toString() ?? 'Customer';
        final double total = _fdbl(d['totalAmt'] ?? d['amount'] ?? d['voucherAmt']);
        final double cash = _fdbl(d['cashAmt']);
        final double bank = _fdbl(d['bankAmt']);
        final double card = _fdbl(d['cardAmt']);
        final double due = _fdbl(d['dueAmt']);
        final isOutward = d['serviceType']?.toString().toLowerCase().contains('outward') ?? false;

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': d['itemName']?.toString() ?? 'Service Charge',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': total,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': total,
          'cardAmt': card,
          'bankAmt': bank,
          'cashAmt': cash,
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? d['remarks']?.toString() ?? '',
          'salesman': '—',
          'categoryName': isOutward ? 'Supplier' : 'Customer',
          'groupHead': isOutward ? 'Supplier For Goods' : 'Sundry Debtors',
          'effectTo': 'Profit And Loss Account',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Dr',
          'totCr': isOutward ? 0.0 : total,
          'totDr': isOutward ? total : 0.0,
          'voucherAmt': isOutward ? 0.0 : total,
          'paymentAmt': isOutward ? total : 0.0,
          'dueAmt': due,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: alteration_entries ─────────────────────────────
      for (final doc in alterationSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['voucherNo']?.toString() ?? d['alterationNo']?.toString() ?? 'ALT-${doc.id.substring(0, 4)}';
        final acName = d['customerName']?.toString() ?? d['acName']?.toString() ?? 'Customer';
        final double amount = _fdbl(d['amount'] ?? d['charges']);
        final double paid = _fdbl(d['paidAmt'] ?? d['cashAmt'] ?? d['bankAmt'] ?? d['cardAmt']);
        final double due = amount - paid;

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': d['itemName']?.toString() ?? 'Alteration Service',
          'carat': '',
          'grossWeight': 0.0,
          'netWeight': 0.0,
          'gstTaxableAmt': amount,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': amount,
          'cardAmt': _fdbl(d['cardAmt']),
          'bankAmt': _fdbl(d['bankAmt']),
          'cashAmt': _fdbl(d['cashAmt'] ?? paid),
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? d['remarks']?.toString() ?? '',
          'salesman': '—',
          'categoryName': 'Customer',
          'groupHead': 'Sundry Debtors',
          'effectTo': 'Profit And Loss Account',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Dr',
          'totCr': amount,
          'totDr': 0.0,
          'voucherAmt': amount,
          'paymentAmt': paid,
          'dueAmt': due,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      // ── Process collection: delivery_challans ──────────────────────────────
      for (final doc in challanSnap.docs) {
        final d = doc.data();
        final vDate = _parseDocDate(d);
        if (vDate == null) continue;
        if (vDate.isBefore(filterStartMidnight) || vDate.isAfter(filterEndDayEnd)) continue;

        final vNo = d['challanNo']?.toString() ?? d['voucherNo']?.toString() ?? 'DC-${doc.id.substring(0, 4)}';
        final acName = d['customerName']?.toString() ?? d['acName']?.toString() ?? 'Customer';
        final double amount = _fdbl(d['totalAmt'] ?? d['amount'] ?? d['voucherAmt']);

        list.add({
          'voucherNo': vNo,
          'voucherDate': vDate,
          'acName': acName,
          'itemName': d['itemName']?.toString() ?? 'Delivery Challan Item',
          'carat': '',
          'grossWeight': _fdbl(d['grossWeight'] ?? d['grossWt']),
          'netWeight': _fdbl(d['netWeight'] ?? d['netWt']),
          'gstTaxableAmt': amount,
          'gstTotal': 0.0,
          'totalGstAmount': 0.0,
          'igstAmt': 0.0,
          'cgstAmt': 0.0,
          'sgstAmt': 0.0,
          'rndDiscount': 0.0,
          'billAmount': amount,
          'cardAmt': 0.0,
          'bankAmt': 0.0,
          'cashAmt': 0.0,
          'panNo': '',
          'gstinNo': '',
          'remark': d['narration']?.toString() ?? d['remarks']?.toString() ?? '',
          'salesman': '—',
          'categoryName': 'Customer',
          'groupHead': 'Sundry Debtors',
          'effectTo': 'Balance Sheet',
          'opBalanceVal': 0.0,
          'opBalanceType': 'Dr',
          'totCr': amount,
          'totDr': 0.0,
          'voucherAmt': amount,
          'paymentAmt': 0.0,
          'dueAmt': amount,
          'docId': doc.id,
          'rawDoc': d,
        });
      }

      if (mounted) setState(() { _rows = list; _loading = false; });
    } catch (e) {
      debugPrint('FullReport load error: $e');
      if (mounted) setState(() => _loading = false);
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

  String _generateCsvString(List<Map<String, dynamic>> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Voucher No,Date,Account Name,Category Name,Group Head,Effect To,'
      'Op. Balance,Tot Cr. (YTD),Tot Dr. (YTD),Total Amt,Paid Amt,Due Amt,'
      'Item Name,Carat,Gross Wt,Net Wt,GST Taxable Amount,GST Total,'
      'Total GST Amount,IGST Amount,CGST Amt,SGST Amt,Rnd Discount,'
      'Bill Amount,Card Amt,Bank Amt,Cash Amt,PAN No,GST No,Remark'
    );

    for (final r in rows) {
      final dateStr = DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime);
      final opVal = r['opBalanceVal'];
      final opBalStr = opVal > 0 ? '$opVal ${r['opBalanceType']}' : '0.00 Cr';

      String clean(dynamic value) {
        if (value == null) return '';
        final str = value.toString().replaceAll('"', '""');
        if (str.contains(',') || str.contains('\n') || str.contains('"')) {
          return '"$str"';
        }
        return str;
      }

      String numFmt(dynamic val) {
        if (val == null || val == 0.0) return '';
        return val.toString();
      }

      buffer.writeln([
        clean(r['voucherNo']),
        clean(dateStr),
        clean(r['acName']),
        clean(r['categoryName']),
        clean(r['groupHead']),
        clean(r['effectTo']),
        clean(opBalStr),
        numFmt(r['totCr']),
        numFmt(r['totDr']),
        numFmt(r['voucherAmt']),
        numFmt(r['paymentAmt']),
        numFmt(r['dueAmt']),
        clean(r['itemName']),
        clean(r['carat']),
        numFmt(r['grossWeight']),
        numFmt(r['netWeight']),
        numFmt(r['gstTaxableAmt']),
        numFmt(r['gstTotal']),
        numFmt(r['totalGstAmount']),
        numFmt(r['igstAmt']),
        numFmt(r['cgstAmt']),
        numFmt(r['sgstAmt']),
        numFmt(r['rndDiscount']),
        numFmt(r['billAmount']),
        numFmt(r['cardAmt']),
        numFmt(r['bankAmt']),
        numFmt(r['cashAmt']),
        clean(r['panNo']),
        clean(r['gstinNo']),
        clean(r['remark']),
      ].join(','));
    }
    return buffer.toString();
  }

  Future<void> _handleDownload(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transaction records to download.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    try {
      final csvContent = _generateCsvString(rows);
      final encodedUri = Uri.encodeComponent(csvContent);
      final csvUri = Uri.parse('data:text/csv;charset=utf-8,$encodedUri');
      
      final launched = await launchUrl(csvUri);
      if (!launched) {
        // Fallback: Copy to clipboard if launch fails
        await Clipboard.setData(ClipboardData(text: csvContent));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to launch downloader. CSV copied to clipboard instead!'),
              backgroundColor: _br,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transactions exported successfully as CSV!'),
              backgroundColor: Color(0xFF2E7D32),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting data: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    List<Map<String, dynamic>> filtered = _rows;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) =>
          r['voucherNo'].toString().toLowerCase().contains(q) ||
          r['acName'].toString().toLowerCase().contains(q) ||
          r['gstinNo'].toString().toLowerCase().contains(q) ||
          r['itemName'].toString().toLowerCase().contains(q)).toList();
    }

    if (_selectedCategoryFilter != 'All') {
      filtered = filtered.where((r) => r['categoryName'] == _selectedCategoryFilter).toList();
    }
    if (_selectedGroupFilter != 'All') {
      filtered = filtered.where((r) => r['groupHead'] == _selectedGroupFilter).toList();
    }
    if (_selectedEffectFilter != 'All') {
      filtered = filtered.where((r) => r['effectTo'] == _selectedEffectFilter).toList();
    }

    if (_selectedSortOption == 'Date: Newest First') {
      filtered.sort((a, b) => (b['voucherDate'] as DateTime).compareTo(a['voucherDate'] as DateTime));
    } else if (_selectedSortOption == 'Date: Oldest First') {
      filtered.sort((a, b) => (a['voucherDate'] as DateTime).compareTo(b['voucherDate'] as DateTime));
    } else if (_selectedSortOption == 'Voucher No: A-Z') {
      filtered.sort((a, b) => (a['voucherNo'] as String).compareTo(a['voucherNo'] as String));
    } else if (_selectedSortOption == 'Voucher No: Z-A') {
      filtered.sort((a, b) => (b['voucherNo'] as String).compareTo(a['voucherNo'] as String));
    } else if (_selectedSortOption == 'Party Name: A-Z') {
      filtered.sort((a, b) => (a['acName'] as String).compareTo(b['acName'] as String));
    } else if (_selectedSortOption == 'Party Name: Z-A') {
      filtered.sort((a, b) => (b['acName'] as String).compareTo(a['acName'] as String));
    } else if (_selectedSortOption == 'Bill Amount: High to Low') {
      filtered.sort((a, b) => (b['billAmount'] as double).compareTo(a['billAmount'] as double));
    } else if (_selectedSortOption == 'Bill Amount: Low to High') {
      filtered.sort((a, b) => (a['billAmount'] as double).compareTo(a['billAmount'] as double));
    } else if (_selectedSortOption == 'Due Amount: High to Low') {
      filtered.sort((a, b) => (b['dueAmt'] as double).compareTo(a['dueAmt'] as double));
    } else if (_selectedSortOption == 'Due Amount: Low to High') {
      filtered.sort((a, b) => (a['dueAmt'] as double).compareTo(b['dueAmt'] as double));
    }

    return filtered;
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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    double totalReceivable = 0.0;
    double totalPayable = 0.0;
    for (final r in filtered) {
      final categoryName = r['categoryName'];
      final double dueAmt = r['dueAmt'] as double;
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
    }

    return SelectionArea(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Title, Date Picker, Download
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'L   Full Report',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6), borderRadius: BorderRadius.circular(10)),
                      child: Text('${filtered.length} records',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4527A0))),
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Year Selector Dropdown
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
                          value: _to.year.toString(),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF8D6E63)),
                          style: const TextStyle(color: Color(0xFF5D4037), fontSize: 11, fontWeight: FontWeight.w600),
                          onChanged: (val) {
                            if (val != null) {
                              final yr = int.parse(val);
                              setState(() {
                                _from = DateTime(yr, _from.month, _from.day);
                                _to = DateTime(yr, _to.month, _to.day, 23, 59, 59, 999);
                              });
                              _load();
                            }
                          },
                          items: ['2024', '2025', '2026', '2027', '2028'].map((String item) {
                            return DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Custom Date Range Picker button
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickRange(context, DateTimeRange(start: _from, end: _to));
                        if (picked != null) {
                          setState(() {
                            _from = picked.start;
                            _to = picked.end;
                          });
                          _load();
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
                        '${DateFormat('dd/MM/yyyy').format(_from)} - ${DateFormat('dd/MM/yyyy').format(_to)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Download button
                    InkWell(
                      onTap: () => _handleDownload(filtered),
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

            // Search Bar & Dropdowns (Filters Container)
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
                            onChanged: (value) => setState(() => _searchQuery = value),
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
                      label: 'Category Name',
                      value: _selectedCategoryFilter,
                      items: ['All', 'Customer', 'Supplier', 'Expense', 'Journal'],
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
            const SizedBox(height: 12),

            // Table card container
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0D8C3)),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _loading
                      ? _loader
                      : filtered.isEmpty
                          ? _emptyState('No transactions found matching the selected filters.')
                          : Scrollbar(
                              controller: _horizontalScrollCtrl,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _horizontalScrollCtrl,
                                scrollDirection: Axis.horizontal,
                                child: Container(
                                  width: 3450,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        color: _bg1,
                                        child: Row(children: [
                                          _th('Voucher No', w: 100),
                                          _th('Date', w: 100),
                                          _th('Account Name', w: 160),
                                          _th('Category Name', w: 110),
                                          _th('Group Head', w: 130),
                                          _th('Effect To', w: 130),
                                          _th('Op. Balance', w: 110, r: true),
                                          _th('Tot Cr. (YTD)', w: 110, r: true),
                                          _th('Tot Dr. (YTD)', w: 110, r: true),
                                          _th('Total Amt (₹)', w: 110, r: true),
                                          _th('Paid Amt (₹)', w: 110, r: true),
                                          _th('Due Amt (₹)', w: 110, r: true),
                                          _th('Item Name', w: 140),
                                          _th('Carat', w: 80),
                                          _th('Gross Wt', w: 100, r: true),
                                          _th('Net Wt', w: 100, r: true),
                                          _th('GST Taxable Amount', w: 120, r: true),
                                          _th('GST Total', w: 90, r: true),
                                          _th('Total GST Amount', w: 110, r: true),
                                          _th('IGST Amount', w: 100, r: true),
                                          _th('CGST Amt', w: 100, r: true),
                                          _th('SGST Amt', w: 100, r: true),
                                          _th('Rnd Discount', w: 100, r: true),
                                          _th('Bill Amount', w: 120, r: true),
                                          _th('Card Amt', w: 100, r: true),
                                          _th('Bank Amt', w: 100, r: true),
                                          _th('Cash Amt', w: 100, r: true),
                                          _th('PAN No', w: 120),
                                          _th('GST No', w: 140),
                                          _th('Remark', w: 160),
                                        ]),
                                      ),
                                      const Divider(height: 1, color: _bdr),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: filtered.length,
                                          itemBuilder: (context, index) {
                                            final r = filtered[index];
                                            final bg = index.isEven ? Colors.white : _bg0;

                                            final double opVal = r['opBalanceVal'];
                                            final String opBalStr = opVal > 0 
                                                ? '${opVal.toStringAsFixed(2)} ${r['opBalanceType']}' 
                                                : '0.00 Cr';

                                            final grossWeightVal = r['grossWeight'];
                                            final String grossWtStr = (grossWeightVal != null && grossWeightVal > 0.0) ? '${(grossWeightVal as double).toStringAsFixed(3)}g' : '—';

                                            final netWeightVal = r['netWeight'];
                                            final String netWtStr = (netWeightVal != null && netWeightVal > 0.0) ? '${(netWeightVal as double).toStringAsFixed(3)}g' : '—';

                                            final gstTaxableAmtVal = r['gstTaxableAmt'];
                                            final String gstTaxableAmtStr = (gstTaxableAmtVal != null && gstTaxableAmtVal > 0.0) ? '₹ ${_fmt(gstTaxableAmtVal as double)}' : '—';

                                            final gstTotalVal = r['gstTotal'];
                                            final String gstTotalStr = (gstTotalVal != null && gstTotalVal > 0.0) ? '${(gstTotalVal as double).toStringAsFixed(1)}%' : '—';

                                            final totalGstAmountVal = r['totalGstAmount'];
                                            final String totalGstAmountStr = (totalGstAmountVal != null && totalGstAmountVal > 0.0) ? '₹ ${_fmt(totalGstAmountVal as double)}' : '—';

                                            final igstAmtVal = r['igstAmt'];
                                            final String igstAmtStr = (igstAmtVal != null && igstAmtVal > 0.0) ? '₹ ${_fmt(igstAmtVal as double)}' : '—';

                                            final cgstAmtVal = r['cgstAmt'];
                                            final String cgstAmtStr = (cgstAmtVal != null && cgstAmtVal > 0.0) ? '₹ ${_fmt(cgstAmtVal as double)}' : '—';

                                            final sgstAmtVal = r['sgstAmt'];
                                            final String sgstAmtStr = (sgstAmtVal != null && sgstAmtVal > 0.0) ? '₹ ${_fmt(sgstAmtVal as double)}' : '—';

                                            final rndDiscountVal = r['rndDiscount'];
                                            final String rndDiscountStr = (rndDiscountVal != null && rndDiscountVal != 0.0) ? '₹ ${_fmt(rndDiscountVal as double)}' : '—';

                                            final caratVal = r['carat'];
                                            final String caratStr = (caratVal != null && caratVal.toString().isNotEmpty && caratVal.toString() != '0') ? caratVal.toString() : '—';

                                            final cardAmtVal = r['cardAmt'];
                                            final String cardAmtStr = (cardAmtVal != null && cardAmtVal > 0.0) ? '₹ ${_fmt(cardAmtVal as double)}' : '—';

                                            final bankAmtVal = r['bankAmt'];
                                            final String bankAmtStr = (bankAmtVal != null && bankAmtVal > 0.0) ? '₹ ${_fmt(bankAmtVal as double)}' : '—';

                                            final cashAmtVal = r['cashAmt'];
                                            final String cashAmtStr = (cashAmtVal != null && cashAmtVal > 0.0) ? '₹ ${_fmt(cashAmtVal as double)}' : '—';

                                            void onDoubleTap() {
                                              if (r['rawDoc'] != null) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) => BillDetailDialog(docData: r['rawDoc']),
                                                );
                                              }
                                            }

                                            return Container(
                                              decoration: BoxDecoration(
                                                color: bg,
                                                border: const Border(
                                                  bottom: BorderSide(color: Color(0xFFF2ECE4)),
                                                ),
                                              ),
                                              child: Row(children: [
                                                _td(r['voucherNo'].toString(), w: 100, bold: true, onDoubleTap: onDoubleTap),
                                                _td(DateFormat('dd/MM/yyyy').format(r['voucherDate'] as DateTime), w: 100, onDoubleTap: onDoubleTap),
                                                _td(r['acName'].toString(), w: 160, onDoubleTap: onDoubleTap),
                                                _td(r['categoryName'].toString(), w: 110, onDoubleTap: onDoubleTap),
                                                _td(r['groupHead'].toString(), w: 130, onDoubleTap: onDoubleTap),
                                                _td(r['effectTo'].toString(), w: 130, onDoubleTap: onDoubleTap),
                                                _td(opBalStr, w: 110, r: true, onDoubleTap: onDoubleTap),
                                                _td(_fmt(r['totCr'] as double), w: 110, r: true, c: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                _td(_fmt(r['totDr'] as double), w: 110, r: true, c: const Color(0xFFC62828), onDoubleTap: onDoubleTap),
                                                _td('₹ ${_fmt(r['voucherAmt'] as double)}', w: 110, r: true, c: const Color(0xFF2C3E50), onDoubleTap: onDoubleTap),
                                                _td('₹ ${_fmt(r['paymentAmt'] as double)}', w: 110, r: true, c: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                _td('₹ ${_fmt(r['dueAmt'] as double)}', w: 110, r: true,
                                                    bold: (r['dueAmt'] as double) > 0,
                                                    c: (r['dueAmt'] as double) > 0 ? const Color(0xFFC62828) : const Color(0xFF2C3E50),
                                                    onDoubleTap: onDoubleTap),
                                                _td(r['itemName'].toString(), w: 140, onDoubleTap: onDoubleTap),
                                                _td(caratStr, w: 80, onDoubleTap: onDoubleTap),
                                                _td(grossWtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(netWtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(gstTaxableAmtStr, w: 120, r: true, onDoubleTap: onDoubleTap),
                                                _td(gstTotalStr, w: 90, r: true, onDoubleTap: onDoubleTap),
                                                _td(totalGstAmountStr, w: 110, r: true, onDoubleTap: onDoubleTap),
                                                _td(igstAmtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(cgstAmtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(sgstAmtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(rndDiscountStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td('₹ ${_fmt(r['billAmount'] as double)}', w: 120, r: true, bold: true, c: const Color(0xFF2C3E50), onDoubleTap: onDoubleTap),
                                                _td(cardAmtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(bankAmtStr, w: 100, r: true, onDoubleTap: onDoubleTap),
                                                _td(cashAmtStr, w: 100, r: true, c: const Color(0xFF2E7D32), onDoubleTap: onDoubleTap),
                                                _td(r['panNo'].toString().isEmpty ? '—' : r['panNo'].toString(), w: 120, onDoubleTap: onDoubleTap),
                                                _td(r['gstinNo'].toString().isEmpty ? '—' : r['gstinNo'].toString(), w: 140, onDoubleTap: onDoubleTap),
                                                _td(r['remark'].toString().isEmpty ? '—' : r['remark'].toString(), w: 160, onDoubleTap: onDoubleTap),
                                          ]),
                                        );
                                      },
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFFDFBF7),
                                      border: Border(
                                        top: BorderSide(color: Color(0xFFE0D8C3), width: 2.0),
                                      ),
                                    ),
                                    child: Row(children: [
                                      _tt('TOTAL', w: 100),
                                      _ttBox('', w: 100),
                                      _ttBox('', w: 160),
                                      _ttBox('', w: 110),
                                      _ttBox('', w: 130),
                                      _ttBox('', w: 130),
                                      _ttBox('', w: 110),
                                      _ttBox(_fmt(filtered.fold(0.0, (s, r) => s + (r['totCr'] as double))), w: 110, r: true),
                                      _ttBox(_fmt(filtered.fold(0.0, (s, r) => s + (r['totDr'] as double))), w: 110, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['voucherAmt'] as double)))}', w: 110, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['paymentAmt'] as double)))}', w: 110, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['dueAmt'] as double)))}', w: 110, r: true,
                                          bold: true,
                                          c: filtered.fold(0.0, (s, r) => s + (r['dueAmt'] as double)) > 0 ? const Color(0xFFC62828) : null),
                                      _ttBox('', w: 140),
                                      _ttBox('', w: 80),
                                      _ttBox('${filtered.fold<double>(0.0, (s, r) => s + (r['grossWeight'] as double)).toStringAsFixed(3)}g', w: 100, r: true),
                                      _ttBox('${filtered.fold<double>(0.0, (s, r) => s + (r['netWeight'] as double)).toStringAsFixed(3)}g', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['gstTaxableAmt'] as double)))}', w: 120, r: true),
                                      _ttBox('', w: 90),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['totalGstAmount'] as double)))}', w: 110, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['igstAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['cgstAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['sgstAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['rndDiscount'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['billAmount'] as double)))}', w: 120, r: true, bold: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['cardAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['bankAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('₹ ${_fmt(filtered.fold(0.0, (s, r) => s + (r['cashAmt'] as double)))}', w: 100, r: true),
                                      _ttBox('', w: 120),
                                      _ttBox('', w: 140),
                                      _ttBox('', w: 160),
                                    ]),
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUMMARY HOVER CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
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
    final String amtStr = '₹ ${NumberFormat('#,##,##0.00', 'en_IN').format(widget.amount)}';

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
                  const SizedBox(height: 6),
                  Text(
                    amtStr,
                    style: TextStyle(
                      fontSize: amtSize,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 6),
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
