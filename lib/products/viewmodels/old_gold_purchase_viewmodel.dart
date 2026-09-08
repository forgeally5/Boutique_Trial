import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../services/local_db_service.dart';
import '../../services/sync_service.dart';
import '../../../models/old_gold_purchase.dart';

enum OldGoldSaveStatus { idle, saving, success, error }

class OldGoldPurchaseViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  OldGoldSaveStatus _status = OldGoldSaveStatus.idle;
  String? _errorMessage;
  String? _lastSavedDocId;

  OldGoldSaveStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _status == OldGoldSaveStatus.saving;
  bool get isSuccess => _status == OldGoldSaveStatus.success;
  String? get lastSavedDocId => _lastSavedDocId;

  // Header Details
  String _voucherNo = '';
  String _bookName = 'URD Purchase';
  String _acName = '';
  String _salesman = '';
  String _placeOfSupply = '';
  DateTime _voucherDate = DateTime.now();
  int _dueDateDays = 0;

  // Item List
  final List<OldGoldPurchaseItem> _items = [];

  // Bottom / Sidebar numeric values
  double _otherCharges = 0.0;
  double _discountAmt = 0.0;
  double _rndDiscount = 0.0;

  double _cashAmt = 0.0;
  double _bankAmt = 0.0;
  double _cardAmt = 0.0;
  double _ogPurchase = 0.0;

  double _previousOS = 0.0;

  // Getters
  String get voucherNo => _voucherNo;
  String get bookName => _bookName;
  String get acName => _acName;
  String get salesman => _salesman;
  String get placeOfSupply => _placeOfSupply;
  DateTime get voucherDate => _voucherDate;
  int get dueDateDays => _dueDateDays;
  DateTime get dueDate => _voucherDate.add(Duration(days: _dueDateDays));

  List<OldGoldPurchaseItem> get items => List.unmodifiable(_items);

  double get otherCharges => _otherCharges;
  double get discountAmt => _discountAmt;
  double get rndDiscount => _rndDiscount;

  double get cashAmt => _cashAmt;
  double get bankAmt => _bankAmt;
  double get cardAmt => _cardAmt;
  double get ogPurchase => _ogPurchase;

  double get previousOS => _previousOS;

  // Setters
  void updateHeader({
    String? voucherNo,
    String? bookName,
    String? acName,
    String? salesman,
    String? placeOfSupply,
    DateTime? voucherDate,
    int? dueDateDays,
  }) {
    if (voucherNo != null) _voucherNo = voucherNo;
    if (bookName != null) _bookName = bookName;
    if (acName != null) _acName = acName;
    if (salesman != null) _salesman = salesman;
    if (placeOfSupply != null) _placeOfSupply = placeOfSupply;
    if (voucherDate != null) {
      _voucherDate = voucherDate;
      fetchNextVoucherNo();
    }
    if (dueDateDays != null) _dueDateDays = dueDateDays;
    notifyListeners();
  }

  void updateFinancials({
    double? otherCharges,
    double? discountAmt,
    double? rndDiscount,
    double? cashAmt,
    double? bankAmt,
    double? cardAmt,
    double? ogPurchase,
    double? previousOS,
  }) {
    if (otherCharges != null) _otherCharges = otherCharges;
    if (discountAmt != null) _discountAmt = discountAmt;
    if (rndDiscount != null) _rndDiscount = rndDiscount;
    if (cashAmt != null) _cashAmt = cashAmt;
    if (bankAmt != null) _bankAmt = bankAmt;
    if (cardAmt != null) _cardAmt = cardAmt;
    if (ogPurchase != null) _ogPurchase = ogPurchase;
    if (previousOS != null) _previousOS = previousOS;
    notifyListeners();
  }

  // Row operations
  void addItem(OldGoldPurchaseItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clearItems() {
    _items.clear();
    notifyListeners();
  }

  // Mathematical computed totals
  double get grossWtTotal => _items.fold(0.0, (acc, item) => acc + item.grossWt);
  double get netWtTotal => _items.fold(0.0, (acc, item) => acc + item.netWt);
  double get fineWtTotal => _items.fold(0.0, (acc, item) => acc + item.fineWt);
  int get pcsTotal => _items.fold(0, (acc, item) => acc + item.pcs);

  double get metalAmtTotal => _items.fold(0.0, (acc, item) => acc + item.metalAmount);
  double get labourAmtTotal => _items.fold(0.0, (acc, item) => acc + item.labourAmount);

  double get totalAmt {
    final computed = metalAmtTotal + labourAmtTotal + _otherCharges - _discountAmt - _rndDiscount;
    return computed < 0 ? 0.0 : computed;
  }

  double get voucherAmt => totalAmt;
  double get paymentAmt => _cashAmt + _bankAmt + _cardAmt + _ogPurchase;
  double get dueAmt {
    final computed = voucherAmt - paymentAmt;
    return computed;
  }

  double get finalDue => dueAmt + _previousOS;

  double get totalWeightWithWast {
    // effective weight + wastage (urdLessWt is the less weight / waste subtracted, so gross minus this or similar)
    return netWtTotal;
  }

  // ─── Generate Voucher No ───────────────────────────────────────────────────
  Future<void> fetchNextVoucherNo() async {
    try {
      final dateStr = "${_voucherDate.day.toString().padLeft(2, '0')}${_voucherDate.month.toString().padLeft(2, '0')}${_voucherDate.year}";
      final prefix = 'EURD/$dateStr';

      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

      if (!isOnline) {
        // Fallback for offline mode if we don't know the exact max sequence
        // The -OFF will be appended during save
        _voucherNo = '${prefix}1';
        notifyListeners();
        return;
      }

      final snap = await _firestore
          .collection('urd_purchases')
          .where('voucherNo', isGreaterThanOrEqualTo: prefix)
          .where('voucherNo', isLessThan: '$prefix\uf8ff')
          .get();

      int maxSeq = 0;
      for (var doc in snap.docs) {
        final vNo = doc.data()['voucherNo']?.toString() ?? '';
        if (vNo.startsWith(prefix)) {
          final seqStr = vNo.substring(prefix.length).replaceAll('-OFF', '');
          final numPart = int.tryParse(seqStr) ?? 0;
          if (numPart > maxSeq) {
            maxSeq = numPart;
          }
        }
      }
      _voucherNo = '$prefix${maxSeq + 1}';
      notifyListeners();
    } catch (e) {
      final dateStr = "${_voucherDate.day.toString().padLeft(2, '0')}${_voucherDate.month.toString().padLeft(2, '0')}${_voucherDate.year}";
      _voucherNo = 'EURD/${dateStr}1';
      notifyListeners();
    }
  }

  // ─── Save Purchase Voucher ──────────────────────────────────────────────────
  Future<void> saveVoucher(String adminEmail) async {
    _status = OldGoldSaveStatus.saving;
    notifyListeners();

    try {
      if (_acName.trim().isEmpty) {
        throw Exception('Account Name is required.');
      }

      await fetchNextVoucherNo(); // Ensure we have the latest sequence

      final purchase = OldGoldPurchase(
        voucherNo: _voucherNo,
        bookName: _bookName,
        acName: _acName.trim(),
        salesman: _salesman,
        placeOfSupply: _placeOfSupply,
        voucherDate: _voucherDate,
        dueDateDays: _dueDateDays,
        dueDate: dueDate,
        items: _items,
        metalAmtTotal: metalAmtTotal,
        labourAmtTotal: labourAmtTotal,
        otherCharges: _otherCharges,
        discountAmt: _discountAmt,
        totalAmt: totalAmt,
        rndDiscount: _rndDiscount,
        cashAmt: _cashAmt,
        bankAmt: _bankAmt,
        cardAmt: _cardAmt,
        ogPurchase: _ogPurchase,
        voucherAmt: voucherAmt,
        paymentAmt: paymentAmt,
        dueAmt: dueAmt,
        previousOS: _previousOS,
        finalDue: finalDue,
        createdBy: adminEmail,
      );

      final data = purchase.toMap();

      final connectivityResult = await Connectivity().checkConnectivity();
      final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);

      if (isOnline) {
        final docRef = await _firestore.collection('urd_purchases').add(data);
        _lastSavedDocId = docRef.id;
      } else {
        if (!_voucherNo.endsWith('-OFF')) {
          _voucherNo = '$_voucherNo-OFF';
          data['voucherNo'] = _voucherNo;
        }
        await LocalDbService().insertEntry('urd_purchases', data, operation: 'ADD');
        SyncService().syncNow();
        _lastSavedDocId = 'offline_dummy_id';
      }

      _status = OldGoldSaveStatus.success;
      notifyListeners();
    } catch (e) {
      _status = OldGoldSaveStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  void reset() {
    _status = OldGoldSaveStatus.idle;
    _errorMessage = null;
    _lastSavedDocId = null;
    _items.clear();
    _otherCharges = 0.0;
    _discountAmt = 0.0;
    _rndDiscount = 0.0;
    _cashAmt = 0.0;
    _bankAmt = 0.0;
    _cardAmt = 0.0;
    _ogPurchase = 0.0;
    _previousOS = 0.0;
    _acName = '';
    _salesman = '';
    _placeOfSupply = '';
    _voucherDate = DateTime.now();
    _dueDateDays = 0;
    fetchNextVoucherNo();
    notifyListeners();
  }

  // ─── Fetch History ─────────────────────────────────────────────────────────
  List<OldGoldPurchase> _history = [];
  List<OldGoldPurchase> get history => _history;

  bool _isLoadingHistory = false;
  bool get isLoadingHistory => _isLoadingHistory;

  Future<void> fetchHistory() async {
    _isLoadingHistory = true;
    notifyListeners();
    try {
      final snap = await _firestore
          .collection('urd_purchases')
          .orderBy('createdAt', descending: true)
          .get();
      _history = snap.docs.map((doc) {
        final data = doc.data();
        return OldGoldPurchase.fromMap(data);
      }).toList();
    } catch (e) {
      _history = [];
    }
    _isLoadingHistory = false;
    notifyListeners();
  }

  Future<void> deleteVoucher(String voucherNo) async {
    try {
      final snap = await _firestore
          .collection('urd_purchases')
          .where('voucherNo', isEqualTo: voucherNo)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.delete();
        _history.removeWhere((v) => v.voucherNo == voucherNo);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  Future<OldGoldPurchase?> updateVoucherPayment(String voucherNo, double additionalPayment, String paymentMode, String adminEmail) async {
    try {
      final snap = await _firestore
          .collection('urd_purchases')
          .where('voucherNo', isEqualTo: voucherNo)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        throw Exception('Voucher not found');
      }

      final doc = snap.docs.first;
      final data = doc.data();

      double currentPaymentAmt = (data['paymentAmt'] as num?)?.toDouble() ?? 0.0;
      double currentFinalDue = (data['finalDue'] as num?)?.toDouble() ?? 0.0;
      double previousOS = (data['previousOS'] as num?)?.toDouble() ?? 0.0;
      double voucherAmt = (data['voucherAmt'] as num?)?.toDouble() ?? 0.0;

      final double newPaymentAmt = currentPaymentAmt + additionalPayment;
      final double newFinalDue = currentFinalDue - additionalPayment;
      final double newDueAmt = newFinalDue - previousOS;

      // Update the parent voucher in Firestore (update payment & outstanding due)
      await doc.reference.update({
        'paymentAmt': newPaymentAmt,
        'dueAmt': newDueAmt,
        'finalDue': newFinalDue,
      });

      // Find receipt index for suffixing
      final receiptsSnap = await _firestore
          .collection('urd_purchases')
          .where('parentVoucherNo', isEqualTo: voucherNo)
          .get();
      final int receiptIndex = receiptsSnap.docs.length + 1;
      final String receiptVoucherNo = '$voucherNo-R$receiptIndex';

      // Determine payment mode breakdown for the receipt
      double rCash = 0.0;
      double rBank = 0.0;
      double rCard = 0.0;
      double rOg = 0.0;
      if (paymentMode == 'Cash') rCash = additionalPayment;
      if (paymentMode == 'Bank') rBank = additionalPayment;
      if (paymentMode == 'Card') rCard = additionalPayment;
      if (paymentMode == 'OG Purchase') rOg = additionalPayment;

      // Build Receipt Voucher document
      final parentModel = OldGoldPurchase.fromMap(data);
      final receipt = OldGoldPurchase(
        voucherNo: receiptVoucherNo,
        bookName: 'Receipt Settlement',
        acName: parentModel.acName,
        salesman: parentModel.salesman,
        placeOfSupply: parentModel.placeOfSupply,
        voucherDate: DateTime.now(),
        dueDateDays: 0,
        dueDate: DateTime.now(),
        items: parentModel.items,
        metalAmtTotal: parentModel.metalAmtTotal,
        labourAmtTotal: parentModel.labourAmtTotal,
        otherCharges: parentModel.otherCharges,
        discountAmt: parentModel.discountAmt,
        totalAmt: parentModel.totalAmt,
        rndDiscount: parentModel.rndDiscount,
        cashAmt: rCash,
        bankAmt: rBank,
        cardAmt: rCard,
        ogPurchase: rOg,
        voucherAmt: voucherAmt,
        paymentAmt: additionalPayment,
        dueAmt: newDueAmt,
        previousOS: previousOS,
        finalDue: newFinalDue,
        createdBy: adminEmail,
        voucherType: 'Receipt',
        parentVoucherNo: voucherNo,
      );

      // Save Receipt in Firestore
      await _firestore.collection('urd_purchases').add(receipt.toMap());

      // Refetch History to sync local lists
      await fetchHistory();

      return receipt;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
