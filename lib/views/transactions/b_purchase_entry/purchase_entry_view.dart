import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../utils/pdf_invoice_api.dart';
import '../../../dialogs/add_customer_dialog.dart';
import '../../../state/admin_state.dart';
import '../../../products/repositories/product_repository.dart';
import '../../../models/item_prefix.dart';
import '../../../services/item_prefix_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/local_db_service.dart';
import '../../../services/sync_service.dart';
import '../../widgets/connection_status_badge.dart';
import '../../../utils/share_helper.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFF9F6F0);

class PurchaseEntryView extends StatefulWidget {
  final AdminState state;
  final VoidCallback? onBack;
  final Map<String, dynamic>? initialData;
  const PurchaseEntryView({super.key, required this.state, this.onBack, this.initialData});

  @override
  State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  String _activeBottomPanel = 'Narration';
  List<String> _extraStyles = [
    'Less Wt',
    'Black Beads',
    'Extra Charges',
    'Hallmark Charge',
    'Kedia',
    'Mani/Moti',
    'Rodium Charges',
    'diamond'
  ];

  double _metalAmt = 0.0;
  double _labourAmt = 0.0;
  double _othCharge = 0.0;

  double _cashAmt = 0.0;
  double _bankAmt = 0.0;
  double _cardAmt = 0.0;
  double _upiAmt = 0.0;
  double _ogPurchaseAmt = 0.0;
  double _goldSchemeAmt = 0.0;
  double _rateApplyAmt = 0.0;
  double _salesReturnAmt = 0.0;
  double _apAmt = 0.0;
  double _rateDiffAmt = 0.0;
  final double _previousOS = 0.0;
  double _discountAmt = 0.0;
  double _rndDiscount = 0.0;
  String _discountCategory = 'On Bill Value';

  double get _baseAmt => _metalAmt + _labourAmt + _othCharge + _rateDiffAmt;
  double get _discountApplicableAmt => _discountCategory == 'On Making Cost' ? _labourAmt : _baseAmt;
  double get _afterDiscount => _baseAmt - _discountAmt;
  double get _cgstAmt => _taxScheme == 'CGST + SGST (Local)' ? _afterDiscount * 0.015 : 0.0;
  double get _sgstAmt => _taxScheme == 'CGST + SGST (Local)' ? _afterDiscount * 0.015 : 0.0;
  double get _igstAmt => _taxScheme == 'IGST (Interstate)' ? _afterDiscount * 0.03 : 0.0;
  double get _gstAmt => _cgstAmt + _sgstAmt + _igstAmt;
  
  double get _totalAmt => _afterDiscount + _gstAmt;
  double get _voucherAmt => _totalAmt - _rndDiscount;
  double get _paymentAmt => _cashAmt + _bankAmt + _cardAmt + _upiAmt + _ogPurchaseAmt + _goldSchemeAmt + _rateApplyAmt + _salesReturnAmt + _apAmt;
  double get _dueAmt => _voucherAmt - _paymentAmt;
  double get _finalDue => _dueAmt + _previousOS;


  late TextEditingController _cashController;
  late TextEditingController _bankController;
  late TextEditingController _cardController;
  late TextEditingController _upiController;
  late TextEditingController _upiRemarksController;
  late TextEditingController _upiRemarks2Controller;
  late TextEditingController _ogPurchaseController;
  late TextEditingController _salesReturnAmtController;
  late TextEditingController _schemeAcNoController;
  late TextEditingController _goldSchemeAmtController;
  late TextEditingController _rateApplyController;
  late TextEditingController _metalSettledWtController;
  late TextEditingController _rateDiffController;
  late TextEditingController _apAmtController;
  
  late TextEditingController _othChargeController;
  late TextEditingController _discountAmtController;
  late TextEditingController _discountPerController;
  late TextEditingController _rndDiscountController;
  late TextEditingController _adjustGstVatController;
  late TextEditingController _dueDateController;

  late TextEditingController _ogGrossWtController;
  late TextEditingController _ogDustWtController;
  late TextEditingController _ogNetWtController;
  late TextEditingController _ogWastageController;
  late TextEditingController _ogFinalWtController;
  late TextEditingController _ogRateController;

  late TextEditingController _voucherNoSuffixController;
  late TextEditingController _voucherTitleController;
  late TextEditingController _acNameController;
  late TextEditingController _salesmanController;
  late TextEditingController _voucherDateController;
  late TextEditingController _gstNumberController;
  late TextEditingController _bankChequeController;
  late TextEditingController _bankRemarksController;
  late TextEditingController _cardMachineController;
  late TextEditingController _cardApprovalController;
  late TextEditingController _cardRemarksController;
  late TextEditingController _narrationController;
  bool _isSaving = false;
  String _voucherNoPrefix = 'PL';

  String get _effectiveVoucherNoPrefix {
    if (widget.state.isOnline) {
      return _voucherNoPrefix;
    } else {
      if (_voucherNoPrefix.contains('-OFF')) {
        return _voucherNoPrefix;
      }
      return '$_voucherNoPrefix-OFF';
    }
  }

  // Bottom Panels Additional State & Controllers
  late TextEditingController _srOriginalInvController;
  late TextEditingController _srTagIdController;
  late TextEditingController _srGrossWtController;
  late TextEditingController _srNetWtController;
  late TextEditingController _srStoneWtController;
  late TextEditingController _srReturnRateController;
  late TextEditingController _srDeductionsController;

  late TextEditingController _gsInstallmentsController;
  late TextEditingController _gsBalanceController;
  late TextEditingController _gsBonusController;

  String _msType = 'Fine Gold';
  late TextEditingController _msAccountController;

  String _invoiceType = 'Tax Invoice (GST)';
  String _taxScheme = 'CGST + SGST (Local)';
  late TextEditingController _voucherBookSeriesController;

  String _selectedRateType = '22KT';
  double _dailyBoardRate = 0.0;

  late TextEditingController _rdBookedRateController;
  late TextEditingController _rdCurrentRateController;

  late TextEditingController _apReceiptNoController;
  double _apOriginalAmt = 0.0;
  
  String _placeOfSupply = 'Tamil Nadu';
  Map<String, dynamic>? _selectedSupplierData;

  final ScrollController _horizontalScrollController = ScrollController();

  final List<PurchaseBillingRow> _billingRows = [];
  int _activeRowIndex = 0;

  final List<String> _itemNameOptions = [];
  List<ItemPrefix> _prefixes = [];
  List<String> _bankNamesList = [];
  String? _selectedBankName;
  List<Map<String, dynamic>> _suppliersList = [];
  String? _selectedSupplierCodeAndName;
  List<String> _salesmanOptions = [];

  String _standardizeState(String? stateStr) {
    if (stateStr == null || stateStr.trim().isEmpty) return 'Tamil Nadu';
    final s = stateStr.trim().toLowerCase();
    if (s.contains('tamil') || s.contains('nadu') || s.contains('tn')) {
      return 'Tamil Nadu';
    } else if (s.contains('kerala') || s.contains('kl')) {
      return 'Kerala';
    } else if (s.contains('karnataka') || s.contains('ka')) {
      return 'Karnataka';
    } else if (s.contains('andhra') || s.contains('ap')) {
      return 'Andhra Pradesh';
    }
    return stateStr.trim();
  }

  final List<String> _groupOptions = [
    '24KT', '22KT', '18KT', '14KT',
    '18D', '22D', 'DI', 'ST',
    'S925', '100T', 'OS', 'PT',
    'OPT', 'BR', 'PACKI', 'AL', 'REP'
  ];

  double _getRateForGroup(String? group) {
    if (group == null) return 0.0;
    
    // First try to fetch the dynamically mapped rate
    final dynamicRate = widget.state.getRateForMetalId(group);
    if (dynamicRate > 0.0) return dynamicRate;

    // Fallback to legacy hardcoded rates
    final rates = widget.state.currentLiveRatesData;
    switch (group) {
      case '24KT': return rates.gold24KTrading;
      case '22KT': return rates.gold22KJewellery;
      case '18KT': return rates.gold18KJewellery;
      case '18D': return rates.diamond18KJewellery;
      case '22D': return rates.diamond22KJewellery;
      case 'DI': return rates.diamondTrading;
      case 'ST': return rates.stoneTrading;
      case 'S925': return rates.silver925;
      case '100T': return rates.pureSilverTrading;
      case 'OS': return rates.oldSilverTrading;
      case 'PT': return rates.platinum;
      case 'OPT': return rates.oldPlatinum;
      case 'AL': return rates.alloys;
      case 'REP': return rates.repairingSampleGold;
      case 'OG': return rates.oldGoldTrading;
      default: return 0.0;
    }
  }

  double _getPurityPercentage(String? groupName) {
    if (groupName == null) return 91.6;
    final upper = groupName.toUpperCase();
    if (upper.contains('24')) return 99.9;
    if (upper.contains('22')) return 91.6;
    if (upper.contains('18')) return 75.0;
    if (upper.contains('14')) return 58.5;
    if (upper.contains('925') || upper.contains('S925')) return 92.5;
    if (upper.contains('999')) return 99.9;
    if (upper.contains('PT') || upper.contains('950')) return 95.0;
    return 91.6;
  }

  Future<void> _fetchNextVoucherNumber() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('bills')
          .get();
      int maxNum = 0; // Default starting sequence
      for (final doc in query.docs) {
        final vNo = doc.data()['voucherNo']?.toString();
        if (vNo != null) {
          final sep = vNo.contains('/') ? '/' : '-';
          if (vNo.contains(sep)) {
            final parts = vNo.split(sep);
            for (final part in parts.reversed) {
              final clean = part.replaceAll('OFF', '').trim();
              final num = int.tryParse(clean);
              if (num != null) {
                if (num > maxNum) {
                  maxNum = num;
                }
                break;
              }
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _voucherNoSuffixController.text = (maxNum + 1).toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching next voucher number: $e');
    }
  }


  String? _ogSelectedPurity;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController();
    _bankController = TextEditingController();
    _cardController = TextEditingController();
    _upiController = TextEditingController();
    _upiRemarksController = TextEditingController();
    _upiRemarks2Controller = TextEditingController();
    _ogPurchaseController = TextEditingController();
    _salesReturnAmtController = TextEditingController();
    _schemeAcNoController = TextEditingController();
    _goldSchemeAmtController = TextEditingController();
    _rateApplyController = TextEditingController();
    _metalSettledWtController = TextEditingController();
    _rateDiffController = TextEditingController();
    _apAmtController = TextEditingController();

    _othChargeController = TextEditingController();
    _discountAmtController = TextEditingController();
    _discountPerController = TextEditingController();
    _rndDiscountController = TextEditingController();
    _adjustGstVatController = TextEditingController();
    _dueDateController = TextEditingController();

    _ogGrossWtController = TextEditingController();
    _ogDustWtController = TextEditingController();
    _ogNetWtController = TextEditingController();
    _ogWastageController = TextEditingController();
    _ogFinalWtController = TextEditingController();
    _ogRateController = TextEditingController();

    _voucherNoSuffixController = TextEditingController(text: '1');
    _voucherTitleController = TextEditingController(text: 'Purchase');
    _acNameController = TextEditingController(text: 'Tamil Nadu Cash Party');
    _salesmanController = TextEditingController(text: 'Staff 1');
    _voucherDateController = TextEditingController(text: DateFormat('dd/MM/yyyy EEE').format(DateTime.now()));
    _gstNumberController = TextEditingController();
    _bankChequeController = TextEditingController();
    _bankRemarksController = TextEditingController();
    _cardMachineController = TextEditingController();
    _cardApprovalController = TextEditingController();
    _cardRemarksController = TextEditingController();
    _narrationController = TextEditingController();

    // Initialize bottom panel controllers
    _srOriginalInvController = TextEditingController();
    _srTagIdController = TextEditingController();
    _srGrossWtController = TextEditingController(text: '0.000');
    _srNetWtController = TextEditingController(text: '0.000');
    _srStoneWtController = TextEditingController(text: '0.000');
    _srReturnRateController = TextEditingController(text: '0.00');
    _srDeductionsController = TextEditingController(text: '0.00');

    _gsInstallmentsController = TextEditingController();
    _gsBalanceController = TextEditingController(text: '0.00');
    _gsBonusController = TextEditingController(text: '0.00');

    _msAccountController = TextEditingController();
    _voucherBookSeriesController = TextEditingController();

    _rdBookedRateController = TextEditingController();
    _rdCurrentRateController = TextEditingController();

    _apReceiptNoController = TextEditingController();

    if (widget.initialData == null) {
      _fetchNextVoucherNumber();
    } else {
      _populateFromInitialData(widget.initialData!);
    }
    _loadMetalGroupsFromBackend();
    _loadMasterItemNames();
    _loadBankNames();
    _loadSuppliers();
    _loadSalesmen();
    _loadPrefixes();
    _loadExtraStyles();
    if (widget.initialData == null) {
      _addBillingRow();
    }
    widget.state.addListener(_onAdminStateChanged);
  }

  void _populateFromInitialData(Map<String, dynamic> data) {
    final vNo = data['voucherNo']?.toString() ?? '';
    final sep = vNo.contains('/') ? '/' : '-';
    if (vNo.contains(sep)) {
      final parts = vNo.split(sep);
      _voucherNoPrefix = parts[0];
      if (parts.contains('OFF')) {
        _voucherNoSuffixController.text = parts.where((p) => p != 'OFF' && p != parts[0]).join(sep);
      } else {
        _voucherNoSuffixController.text = parts.sublist(1).join(sep);
      }
    } else {
      _voucherNoSuffixController.text = vNo;
    }

    final rawDate = data['voucherDate'];
    if (rawDate is Timestamp) {
      _voucherDateController.text = DateFormat('dd/MM/yyyy EEE').format(rawDate.toDate());
    } else if (rawDate != null) {
      _voucherDateController.text = rawDate.toString();
    }

    _voucherTitleController.text = data['voucherTitle']?.toString() ?? 'Purchase';
    _acNameController.text = data['acName']?.toString() ?? 'Tamil Nadu Cash Party';
    _salesmanController.text = data['salesman']?.toString() ?? 'Staff 1';
    _placeOfSupply = data['placeOfSupply']?.toString() ?? 'Tamil Nadu';
    _dueDateController.text = data['dueDate']?.toString() ?? '';
    _narrationController.text = data['narration']?.toString() ?? '';
    _gstNumberController.text = (data['supplierDetails'] as Map?)?['gstin']?.toString() ?? '';
    _bankChequeController.text = data['bankChequeNo']?.toString() ?? '';
    _bankRemarksController.text = data['bankRemarks']?.toString() ?? '';
    _cardMachineController.text = data['cardMachine']?.toString() ?? '';
    _cardApprovalController.text = data['cardApprovalNo']?.toString() ?? '';
    _cardRemarksController.text = data['cardRemarks']?.toString() ?? '';
    _selectedBankName = data['bankName']?.toString();

    _cashController.text = (data['cashAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _bankController.text = (data['bankAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _cardController.text = (data['cardAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _upiController.text = (data['upiAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _upiRemarksController.text = data['upiRefNo']?.toString() ?? '';
    _upiRemarks2Controller.text = data['upiRemarks']?.toString() ?? '';
    _ogPurchaseController.text = (data['ogPurchaseAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _salesReturnAmtController.text = (data['salesReturnAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _schemeAcNoController.text = data['schemeAcNo']?.toString() ?? '';
    _goldSchemeAmtController.text = (data['goldSchemeAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _rateApplyController.text = (data['rateApplyAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _metalSettledWtController.text = (data['metalSettledWt'] as num?)?.toStringAsFixed(3) ?? '';
    _rateDiffController.text = (data['rateDiffAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _apAmtController.text = (data['apAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _othChargeController.text = (data['othCharge'] as num?)?.toStringAsFixed(2) ?? '';
    _discountAmtController.text = (data['discountAmt'] as num?)?.toStringAsFixed(2) ?? '';
    _rndDiscountController.text = (data['rndDiscount'] as num?)?.toStringAsFixed(2) ?? '';
    _ogGrossWtController.text = (data['ogGrossWt'] as num?)?.toStringAsFixed(3) ?? '';
    _ogDustWtController.text = (data['ogDustWt'] as num?)?.toStringAsFixed(3) ?? '';
    _ogNetWtController.text = (data['ogNetWt'] as num?)?.toStringAsFixed(3) ?? '';
    _ogWastageController.text = (data['ogWastage'] as num?)?.toStringAsFixed(3) ?? '';
    _ogFinalWtController.text = (data['ogFinalWt'] as num?)?.toStringAsFixed(3) ?? '';
    _ogRateController.text = (data['ogRate'] as num?)?.toStringAsFixed(2) ?? '';

    // Populate new bottom panels fields
    _srOriginalInvController.text = data['srOriginalInvNo']?.toString() ?? '';
    _srTagIdController.text = data['srTagId']?.toString() ?? '';
    _srGrossWtController.text = (data['srGrossWt'] as num?)?.toStringAsFixed(3) ?? '0.000';
    _srNetWtController.text = (data['srNetWt'] as num?)?.toStringAsFixed(3) ?? '0.000';
    _srStoneWtController.text = (data['srStoneWt'] as num?)?.toStringAsFixed(3) ?? '0.000';
    _srReturnRateController.text = (data['srReturnRate'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _srDeductionsController.text = (data['srDeductions'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _gsInstallmentsController.text = (data['gsInstallmentsPaid'] ?? '0').toString();
    _gsBalanceController.text = (data['gsBalance'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _gsBonusController.text = (data['gsBonus'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _msType = data['msType']?.toString() ?? 'Fine Gold';
    _msAccountController.text = data['msAccount']?.toString() ?? '';
    _invoiceType = data['invoiceType']?.toString() ?? 'Tax Invoice (GST)';
    _taxScheme = data['taxScheme']?.toString() ?? 'CGST + SGST (Local)';
    _voucherBookSeriesController.text = data['voucherBookSeries']?.toString() ?? '';
    _rdBookedRateController.text = (data['rdBookedRate'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _rdCurrentRateController.text = (data['rdCurrentRate'] as num?)?.toStringAsFixed(2) ?? '0.00';
    _apReceiptNoController.text = data['apReceiptNo']?.toString() ?? '';
    _apOriginalAmt = (data['apOriginalAmt'] as num?)?.toDouble() ?? 0.0;

    _selectedSupplierData = data['supplierDetails'] as Map<String, dynamic>?;

    _cashAmt = (data['cashAmt'] as num?)?.toDouble() ?? 0.0;
    _bankAmt = (data['bankAmt'] as num?)?.toDouble() ?? 0.0;
    _cardAmt = (data['cardAmt'] as num?)?.toDouble() ?? 0.0;
    _upiAmt = (data['upiAmt'] as num?)?.toDouble() ?? 0.0;
    _ogPurchaseAmt = (data['ogPurchaseAmt'] as num?)?.toDouble() ?? 0.0;
    _salesReturnAmt = (data['salesReturnAmt'] as num?)?.toDouble() ?? 0.0;
    _goldSchemeAmt = (data['goldSchemeAmt'] as num?)?.toDouble() ?? 0.0;
    _rateApplyAmt = (data['rateApplyAmt'] as num?)?.toDouble() ?? 0.0;
    _rateDiffAmt = (data['rateDiffAmt'] as num?)?.toDouble() ?? 0.0;
    _apAmt = (data['apAmt'] as num?)?.toDouble() ?? 0.0;
    _othCharge = (data['othCharge'] as num?)?.toDouble() ?? 0.0;
    _discountAmt = (data['discountAmt'] as num?)?.toDouble() ?? 0.0;
    _rndDiscount = (data['rndDiscount'] as num?)?.toDouble() ?? 0.0;

    final rawItems = data['items'] as List<dynamic>? ?? [];
    for (final item in rawItems) {
      final itemMap = item as Map<String, dynamic>? ?? {};
      final row = PurchaseBillingRow();
      row.selectedItem = itemMap['name']?.toString() ?? '';
      row.labelNoController.text = itemMap['tagId']?.toString() ?? '';
      row.selectedGroup = itemMap['group']?.toString() ?? itemMap['purity']?.toString();
      row.grossWtController.text = (itemMap['grossWeight'] as num?)?.toStringAsFixed(3) ?? '0.000';
      row.othWtController.text = (itemMap['othWt'] as num?)?.toStringAsFixed(3) ?? '0.000';
      row.netWtController.text = (itemMap['netWeight'] as num?)?.toStringAsFixed(3) ?? '0.000';
      row.pcsController.text = (itemMap['pcs'] as num?)?.toInt().toString() ?? '1';
      row.metalRateController.text = (itemMap['rate'] as num?)?.toStringAsFixed(2) ?? '0.00';
      row.metalAmt = (itemMap['metalAmt'] as num?)?.toDouble() ?? 0.0;
      row.totMetalAmt = (itemMap['totMetalAmt'] as num?)?.toDouble() ?? row.metalAmt;
      row.labourOn = itemMap['labourOn']?.toString() ?? 'Per Gram Net Wt';
      row.labourPerController.text = (itemMap['labourRate'] as num?)?.toStringAsFixed(2) ?? '0.00';
      row.labourAmt = (itemMap['labourAmt'] as num?)?.toDouble() ?? 0.0;
      row.otherWtChecked = itemMap['othWtChecked'] == true;
      row.otherWtStyle = itemMap['othWtStyle']?.toString() ?? 'Less Wt';
      final rawExtra = itemMap['extraCharges'] as List<dynamic>? ?? [];
      for (final sr in rawExtra) {
        final srMap = sr as Map<String, dynamic>? ?? {};
        final subRow = PurchaseSubBillingRow();
        subRow.styleName = srMap['styleName']?.toString() ?? 'Less Wt';
        subRow.weightController.text = (srMap['weight'] as num?)?.toStringAsFixed(3) ?? '0.000';
        subRow.pcsController.text = (srMap['pcs'] as num?)?.toInt().toString() ?? '1';
        subRow.rateController.text = (srMap['rate'] as num?)?.toStringAsFixed(2) ?? '0.00';
        subRow.labourPerController.text = (srMap['labourRate'] as num?)?.toStringAsFixed(2) ?? '0.00';
        subRow.labourOn = srMap['labourOn']?.toString() ?? 'Per Piece';
        subRow.metalAmt = (srMap['amount'] as num?)?.toDouble() ?? 0.0;
        subRow.labourAmt = (srMap['labourAmt'] as num?)?.toDouble() ?? 0.0;
        row.subRows.add(subRow);
      }
      _billingRows.add(row);
    }
    if (_billingRows.isEmpty) _addBillingRow();
    _activeRowIndex = 0;
    _onRowDataChanged();
  }

  void _onAdminStateChanged() {
    if (mounted) {
      _loadMetalGroupsFromBackend();
      _loadMasterItemNames();
      _loadBankNames();
      _loadSalesmen();
      _loadPrefixes();
    }
  }

  Future<void> _loadSalesmen() async {
    try {
      final list = await ProductRepository().getUniqueSalesmen();
      if (mounted) {
        setState(() {
          _salesmanOptions = list;
          if (!_salesmanOptions.contains(_salesmanController.text) && _salesmanOptions.isNotEmpty) {
            _salesmanController.text = _salesmanOptions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSuppliers() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('suppliers').get();
      final list = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      if (mounted) {
        setState(() {
          _suppliersList = list;
          if (_selectedSupplierData != null) {
            final code = (_selectedSupplierData!['supplierCode'] ?? _selectedSupplierData!['id'] ?? '').toString();
            final name = (_selectedSupplierData!['name'] ?? _selectedSupplierData!['companyName'] ?? '').toString();
            _selectedSupplierCodeAndName = "$code - $name";
          } else {
            _selectedSupplierCodeAndName = 'Cash Party';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBankNames() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('book_names').get();
      final list = snap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted) {
        setState(() {
          _bankNamesList = list;
          if (list.isNotEmpty) _selectedBankName = list.first;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPrefixes() async {
    try {
      final list = await ItemPrefixService().getAllItemPrefixes();
      if (mounted) {
        setState(() {
          _prefixes = list;
        });
      }
    } catch (_) {}
  }

  void _updatePrefixConfigForRow(PurchaseBillingRow row) {
    String tag = row.labelNoController.text.trim();
    ItemPrefix? matched;

    if (tag.isNotEmpty) {
      final match = RegExp(r'^([a-zA-Z]+)').firstMatch(tag);
      if (match != null) {
        String pfx = match.group(1)!;
        try {
          matched = _prefixes.firstWhere(
            (p) => p.prefix.toUpperCase() == pfx.toUpperCase(),
          );
        } catch (_) {}
      }
    }

    if (matched == null && row.selectedItem.isNotEmpty) {
      try {
        matched = _prefixes.firstWhere(
          (p) => p.itemName.toUpperCase() == row.selectedItem.toUpperCase(),
        );
      } catch (_) {}
    }

    if (matched != null) {
      if (row.requireOtherWt != matched.reqOtherWeight) {
        row.requireOtherWt = matched.reqOtherWeight;
        row.otherWtChecked = matched.reqOtherWeight;
      }
      row.netWtAccessible = matched.netWtAccessible;
    } else {
      if (row.requireOtherWt != false) {
        row.requireOtherWt = false;
        row.otherWtChecked = false;
      }
      row.netWtAccessible = false;
    }
  }

  Future<void> _loadMasterItemNames() async {
    try {
      final names = await ProductRepository().getUniqueItemNames();
      if (mounted) {
        setState(() {
          _itemNameOptions.clear();
          _itemNameOptions.addAll(names);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExtraStyles() async {
    try {
      final styles = await ProductRepository().getUniqueExtraStyles();
      if (mounted) {
        setState(() {
          _extraStyles = styles;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMetalGroupsFromBackend() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('metal_groups_master').get();
      final set = <String>{
        '24KT', '22KT', '18KT', '14KT',
        '18D', '22D', 'DI', 'ST',
        'S925', '100T', 'OS', 'PT',
        'OPT', 'BR', 'PACKI', 'AL', 'REP'
      };
      if (snap.docs.isNotEmpty) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final mId = data['metalId']?.toString() ?? '';
          if (mId.isNotEmpty) {
            set.add(mId);
          }
        }
      }
      if (mounted) {
        setState(() {
          _groupOptions.clear();
          _groupOptions.addAll(set);
          if (_ogSelectedPurity == null && _groupOptions.isNotEmpty) {
            _ogSelectedPurity = _groupOptions.contains('22KT') ? '22KT' : _groupOptions.first;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.state.removeListener(_onAdminStateChanged);
    _cashController.dispose();
    _bankController.dispose();
    _cardController.dispose();
    _upiController.dispose();
    _upiRemarksController.dispose();
    _upiRemarks2Controller.dispose();
    _ogPurchaseController.dispose();
    _salesReturnAmtController.dispose();
    _schemeAcNoController.dispose();
    _goldSchemeAmtController.dispose();
    _rateApplyController.dispose();
    _metalSettledWtController.dispose();
    _rateDiffController.dispose();
    _apAmtController.dispose();

    _othChargeController.dispose();
    _discountAmtController.dispose();
    _discountPerController.dispose();
    _rndDiscountController.dispose();
    _adjustGstVatController.dispose();
    _dueDateController.dispose();

    _ogGrossWtController.dispose();
    _ogDustWtController.dispose();
    _ogNetWtController.dispose();
    _ogWastageController.dispose();
    _ogFinalWtController.dispose();
    _ogRateController.dispose();

    _voucherNoSuffixController.dispose();
    _voucherTitleController.dispose();
    _acNameController.dispose();
    _salesmanController.dispose();
    _voucherDateController.dispose();
    _gstNumberController.dispose();
    _bankChequeController.dispose();
    _bankRemarksController.dispose();
    _cardMachineController.dispose();
    _cardApprovalController.dispose();
    _cardRemarksController.dispose();
    _narrationController.dispose();
    _horizontalScrollController.dispose();

    // Dispose new controllers
    _srOriginalInvController.dispose();
    _srTagIdController.dispose();
    _srGrossWtController.dispose();
    _srNetWtController.dispose();
    _srStoneWtController.dispose();
    _srReturnRateController.dispose();
    _srDeductionsController.dispose();

    _gsInstallmentsController.dispose();
    _gsBalanceController.dispose();
    _gsBonusController.dispose();

    _msAccountController.dispose();
    _voucherBookSeriesController.dispose();

    _rdBookedRateController.dispose();
    _rdCurrentRateController.dispose();

    _apReceiptNoController.dispose();

    for (var row in _billingRows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addBillingRow() {
    final row = PurchaseBillingRow();
    row.grossWtController.addListener(_onRowDataChanged);
    row.othWtController.addListener(_onRowDataChanged);
    row.netWtController.addListener(_onRowDataChanged);
    row.pcsController.addListener(_onRowDataChanged);
    row.metalRateController.addListener(_onRowDataChanged);
    row.labourPerController.addListener(_onRowDataChanged);
    setState(() {
      _billingRows.add(row);
      _activeRowIndex = _billingRows.length - 1;
    });
    _onRowDataChanged();
  }

  void _deleteBillingRow(int index) {
    if (_billingRows.length <= 1) return;
    setState(() {
      final removed = _billingRows.removeAt(index);
      removed.dispose();
      if (_activeRowIndex >= _billingRows.length) {
        _activeRowIndex = _billingRows.length - 1;
      }
    });
    _onRowDataChanged();
  }

  void _onRowDataChanged() {
    double totalMetalAmt = 0.0;
    double totalLabourAmt = 0.0;

    for (var row in _billingRows) {
      _updatePrefixConfigForRow(row);
      double grossWt = double.tryParse(row.grossWtController.text) ?? 0.0;
      double othWt = 0.0;
      double netWt = 0.0;

      if (row.otherWtChecked) {
        double sumSubWt = 0.0;
        for (var sr in row.subRows) {
          sumSubWt += double.tryParse(sr.weightController.text) ?? 0.0;
        }

        if (row.netWtFocus.hasFocus && row.netWtAccessible) {
          netWt = double.tryParse(row.netWtController.text) ?? 0.0;
          othWt = grossWt - netWt;
          if (othWt < 0) othWt = 0.0;
          
          if (row.subRows.isNotEmpty) {
            final firstSubWtStr = othWt.toStringAsFixed(3);
            if (row.subRows.first.weightController.text != firstSubWtStr) {
              row.subRows.first.weightController.removeListener(_onRowDataChanged);
              row.subRows.first.weightController.text = firstSubWtStr;
              row.subRows.first.weightController.addListener(_onRowDataChanged);
            }
          }
          final othWtStr = othWt.toStringAsFixed(3);
          if (row.othWtController.text != othWtStr) {
            row.othWtController.text = othWtStr;
          }
        } else {
          othWt = sumSubWt;
          netWt = grossWt - othWt;
          if (netWt < 0) netWt = 0.0;
          final netWtStr = netWt.toStringAsFixed(3);
          if (row.netWtController.text != netWtStr) {
            row.netWtController.text = netWtStr;
          }
          final othWtStr = othWt.toStringAsFixed(3);
          if (row.othWtController.text != othWtStr) {
            row.othWtController.text = othWtStr;
          }
        }
      } else {
        othWt = 0.0;
        netWt = grossWt;
        if (row.othWtController.text != '0.000') {
          row.othWtController.text = '0.000';
        }
        final netWtStr = netWt.toStringAsFixed(3);
        if (row.netWtController.text != netWtStr) {
          row.netWtController.text = netWtStr;
        }
      }

      double pcs = double.tryParse(row.pcsController.text) ?? 1.0;
      if (pcs <= 0) pcs = 1.0;
      double metalRate = double.tryParse(row.metalRateController.text) ?? 0.0;
      double labPer = double.tryParse(row.labourPerController.text) ?? 0.0;

      row.metalAmt = netWt * metalRate;
      row.totMetalAmt = row.metalAmt * pcs;

      if (row.labourOn == 'Per Gram Gross Wt') {
        row.labourAmt = grossWt * labPer;
      } else if (row.labourOn == 'Per Gram Net Wt') {
        row.labourAmt = netWt * labPer;
      } else if (row.labourOn == 'Per Gram Fine Wt') {
        double purityPer = _getPurityPercentage(row.selectedGroup);
        double fineWt = netWt * (purityPer / 100.0);
        row.labourAmt = fineWt * labPer;
      } else if (row.labourOn == 'Per Piece') {
        row.labourAmt = pcs * labPer;
      } else if (row.labourOn == 'Percentage' || row.labourOn == 'Percentage on Net Wt') {
        row.labourAmt = (row.metalAmt * labPer) / 100.0;
      } else if (row.labourOn == 'Percentage on Gross Wt') {
        double grossAmt = grossWt * metalRate;
        row.labourAmt = (grossAmt * labPer) / 100.0;
      } else if (row.labourOn == 'Percentage on Fine Wt') {
        double purityPer = _getPurityPercentage(row.selectedGroup);
        double fineWt = netWt * (purityPer / 100.0);
        double fineAmt = fineWt * metalRate;
        row.labourAmt = (fineAmt * labPer) / 100.0;
      } else if (row.labourOn == 'Fixed') {
        row.labourAmt = labPer;
      } else {
        row.labourAmt = 0.0;
      }

      if (row.otherWtChecked) {
        for (var sr in row.subRows) {
          double subWt = double.tryParse(sr.weightController.text) ?? 0.0;
          double subPcs = double.tryParse(sr.pcsController.text) ?? 0.0;
          double subRate = double.tryParse(sr.rateController.text) ?? 0.0;
          double subLabPer = double.tryParse(sr.labourPerController.text) ?? 0.0;

          if (subWt > 0) {
            sr.metalAmt = subWt * subRate;
          } else {
            sr.metalAmt = subPcs * subRate;
          }
          sr.totMetalAmt = sr.metalAmt * pcs;

          if (sr.labourOn == 'Per Gram Gross Wt') {
            sr.labourAmt = grossWt * subLabPer;
          } else if (sr.labourOn == 'Per Gram Net Wt') {
            sr.labourAmt = subWt * subLabPer;
          } else if (sr.labourOn == 'Per Gram Fine Wt') {
            double purityPer = _getPurityPercentage(row.selectedGroup);
            double fineWt = subWt * (purityPer / 100.0);
            sr.labourAmt = fineWt * subLabPer;
          } else if (sr.labourOn == 'Per Piece') {
            sr.labourAmt = subPcs * subLabPer;
          } else if (sr.labourOn == 'Percentage' || sr.labourOn == 'Percentage on Net Wt') {
            sr.labourAmt = (sr.metalAmt * subLabPer) / 100.0;
          } else if (sr.labourOn == 'Percentage on Gross Wt') {
            double grossAmt = grossWt * subRate;
            sr.labourAmt = (grossAmt * subLabPer) / 100.0;
          } else if (sr.labourOn == 'Percentage on Fine Wt') {
            double purityPer = _getPurityPercentage(row.selectedGroup);
            double fineAmt = sr.metalAmt * (purityPer / 100.0);
            sr.labourAmt = (fineAmt * subLabPer) / 100.0;
          } else if (sr.labourOn == 'Fixed') {
            sr.labourAmt = subLabPer;
          } else {
            sr.labourAmt = 0.0;
          }

          row.metalAmt += sr.metalAmt;
          row.totMetalAmt += sr.totMetalAmt;
          row.labourAmt += sr.labourAmt;
        }
      }

      totalMetalAmt += row.metalAmt;
      totalLabourAmt += row.labourAmt;
    }

    setState(() {
      _metalAmt = totalMetalAmt;
      _labourAmt = totalLabourAmt;
      
      double per = double.tryParse(_discountPerController.text) ?? 0.0;
      if (per > 0) {
        double amt = _discountApplicableAmt * (per / 100);
        _discountAmtController.text = amt.toStringAsFixed(2);
      }
      
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    setState(() {});
  }

  void _calculateOldGoldAmount() {
    double gross = double.tryParse(_ogGrossWtController.text) ?? 0.0;
    double dust = double.tryParse(_ogDustWtController.text) ?? 0.0;
    double net = gross - dust;
    if (net < 0) net = 0.0;
    
    if (_ogNetWtController.text != net.toStringAsFixed(3)) {
      _ogNetWtController.text = net.toStringAsFixed(3);
    }

    double wastage = double.tryParse(_ogWastageController.text) ?? 0.0;
    double finalWt = net * (1 - (wastage / 100));
    
    if (_ogFinalWtController.text != finalWt.toStringAsFixed(3)) {
      _ogFinalWtController.text = finalWt.toStringAsFixed(3);
    }

    double rate = double.tryParse(_ogRateController.text) ?? 0.0;
    double amount = finalWt * rate;
    
    if (_ogPurchaseController.text != amount.toStringAsFixed(2)) {
      _ogPurchaseController.text = amount.toStringAsFixed(2);
      _recalculateTotals();
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
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
            dialogTheme: const DialogThemeData(backgroundColor: _bg),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Widget _buildGridCell({
    required double width,
    required Widget child,
    Color? backgroundColor,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Container(
      width: width,
      height: 32,
      alignment: alignment,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        border: const Border(
          right: BorderSide(color: _border),
          bottom: BorderSide(color: _border),
        ),
      ),
      child: child,
    );
  }

  Widget _buildGridTextField({
    required TextEditingController controller,
    required double width,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    TextAlign textAlign = TextAlign.left,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    VoidCallback? onTap,
    Widget? suffixIcon,
    FocusNode? focusNode,
  }) {
    return _buildGridCell(
      width: width,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboardType,
        textAlign: textAlign,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        style: const TextStyle(fontSize: 11, color: Colors.black87),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildGridDropdown({
    required double width,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? hint,
  }) {
    final cleanItems = items.toSet().toList();
    final safeValue = (value != null && cleanItems.contains(value)) ? value : null;

    return _buildGridCell(
      width: width,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          hint: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(hint ?? "Select", style: const TextStyle(fontSize: 11, color: Colors.black54)),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
          items: cleanItems.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(val, style: const TextStyle(fontSize: 11, color: Colors.black87)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildGridCheckbox({
    required bool value,
    required double width,
    required ValueChanged<bool?> onChanged,
    Color? backgroundColor,
  }) {
    return _buildGridCell(
      width: width,
      backgroundColor: backgroundColor,
      alignment: Alignment.center,
      child: SizedBox(
        height: 24,
        width: 24,
        child: Checkbox(
          activeColor: const Color(0xFFCA6F1E),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Helpers for building small, dense input fields
  Widget _buildTextField(String label, {double width = 150, bool isExpanded = false, TextEditingController? controller, ValueChanged<String>? onChanged, VoidCallback? onTap, bool readOnly = false, Widget? suffixIcon}) {
    Widget child = SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        decoration: InputDecoration(
          fillColor: Colors.white,
          filled: true,
          suffixIcon: suffixIcon,
          suffixIconConstraints: suffixIcon != null ? const BoxConstraints(minWidth: 24, minHeight: 24) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: _brown),
          ),
        ),
      ),
    );

    if (isExpanded) {
      return Row(
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
          ],
          Expanded(child: child),
        ],
      );
    }

    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.isNotEmpty) ...[
            Text(label, style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }


  Widget _buildButton(String text, {VoidCallback? onPressed}) {
    return SizedBox(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _brown,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: onPressed ?? () {},
        child: Text(text),
      ),
    );
  }
  
  Widget _buildOutlineButton(String text, {VoidCallback? onPressed, bool isActive = false}) {
    return SizedBox(
      height: 28,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isActive ? _brown : Colors.transparent,
          foregroundColor: isActive ? Colors.white : _brown,
          side: BorderSide(color: isActive ? _brown : _border),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: onPressed ?? () {},
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double minWidth = constraints.maxWidth > 1400 ? constraints.maxWidth : 1400;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal, // To allow scrolling for wide tables
            child: SizedBox(
              width: minWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Purchase Entry",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                        fontFamily: 'serif',
                      ),
                    ),
                    ConnectionStatusBadge(state: widget.state),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Form Area (Left)
                      Expanded(
                        flex: 75,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTopSection(),
                            const SizedBox(height: 16),
                            _buildTableSection(),
                            const SizedBox(height: 16),
                            _buildBottomLeftSection(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Sidebar Area (Right)
                      Expanded(
                        flex: 25,
                        child: _buildRightSidebar(),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      );
      },
    ),
    );
  }

  InputDecoration _smallDecoration() {
    return InputDecoration(
      fillColor: Colors.white,
      filled: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
    );
  }

  Widget _buildDropdownWithLabel(String label, {required String initialValue, required List<String> items, required ValueChanged<String?> onChanged, double? width, bool isExpanded = false}) {
    final cleanItems = items.toSet().toList();
    final safeValue = cleanItems.contains(initialValue) ? initialValue : (cleanItems.isNotEmpty ? cleanItems.first : null);

    final drop = SizedBox(
      height: 28,
      child: DropdownButtonFormField<String>(
        initialValue: safeValue,
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
        decoration: _smallDecoration(),
        style: const TextStyle(fontSize: 12, color: Colors.black87),
        items: cleanItems.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
    final row = Row(
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
        ],
        Expanded(child: drop),
      ],
    );
    if (isExpanded) {
      return row;
    }
    return SizedBox(
      width: width ?? 150,
      child: row,
    );
  }

  Widget _buildTopSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column of Top Section
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Row(
                children: [
                  _buildDropdownWithLabel("Voucher No.", width: 150, initialValue: _voucherNoPrefix, items: ['PL', 'PR'], onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _voucherNoPrefix = val;
                      });
                    }
                  }),
                  const SizedBox(width: 4),
                  _buildTextField("", width: 80, controller: _voucherNoSuffixController, readOnly: true),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField("", width: double.infinity, controller: _voucherTitleController)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTextField("Tot. Metal Amt.", width: double.infinity, controller: TextEditingController(text: _metalAmt.toStringAsFixed(2)), readOnly: true)),
                  const SizedBox(width: 8),
                  _buildButton("Cash Party", onPressed: () {
                    setState(() {
                      _selectedSupplierCodeAndName = 'Cash Party';
                      _acNameController.text = 'Tamil Nadu Cash Party';
                      _placeOfSupply = 'Tamil Nadu';
                      _gstNumberController.text = '';
                      _selectedSupplierData = null;
                      _recalculateTotals();
                    });
                  }),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildDropdownWithLabel(
                            "A/c. Name",
                            isExpanded: true,
                            initialValue: _selectedSupplierCodeAndName ?? 'Cash Party',
                             items: ['Cash Party', ..._suppliersList
                                .where((e) => e['supplierCode'] != null && e['supplierCode'].toString().trim().isNotEmpty)
                                .map((e) {
                                  final code = e['supplierCode'].toString().trim();
                                  final name = (e['name'] ?? e['companyName'] ?? '').toString();
                                  return "$code - $name";
                                })],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedSupplierCodeAndName = val;
                                  if (val == 'Cash Party') {
                                    _acNameController.text = 'Tamil Nadu Cash Party';
                                    _placeOfSupply = 'Tamil Nadu';
                                    _gstNumberController.text = '';
                                    _selectedSupplierData = null;
                                  } else {
                                    final parts = val.split(' - ');
                                    final code = parts[0];
                                    final supplier = _suppliersList.firstWhere((e) => (e['supplierCode'] ?? e['id'] ?? '') == code);
                                    _selectedSupplierData = supplier;
                                    _acNameController.text = supplier['name'] ?? supplier['companyName'] ?? '';
                                    _placeOfSupply = _standardizeState(supplier['state']?.toString());
                                    _gstNumberController.text = (supplier['gstin'] ?? supplier['vatNumber'] ?? '').toString();
                                  }
                                  _recalculateTotals();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 28,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _selectedSupplierData != null ? const Color(0xFF1E3A8A) : _brown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            icon: Icon(_selectedSupplierData != null ? Icons.edit : Icons.add, size: 14),
                            label: Text(_selectedSupplierData != null ? 'Edit Supplier' : 'Add Supplier', style: const TextStyle(fontSize: 11)),
                            onPressed: () async {
                              Map<String, dynamic>? fullSupplierData;
                              if (_selectedSupplierData != null) {
                                final code = (_selectedSupplierData!['supplierCode'] ?? _selectedSupplierData!['id'] ?? '').toString().trim();
                                final name = (_selectedSupplierData!['name'] ?? _selectedSupplierData!['companyName'] ?? '').toString().trim();
                                if (code.isNotEmpty || name.isNotEmpty) {
                                  try {
                                    fullSupplierData = _suppliersList.firstWhere(
                                      (e) => (e['supplierCode']?.toString().trim() == code && code.isNotEmpty) || 
                                             (e['id']?.toString().trim() == code && code.isNotEmpty) || 
                                             ((e['name'] ?? e['companyName'] ?? '').toString().trim() == name && name.isNotEmpty),
                                    );
                                  } catch (_) {}
                                }
                              }
                              final result = await showDialog<Map<String, dynamic>>(
                                context: context,
                                builder: (context) => AddCustomerDialog(
                                  isSupplier: true,
                                  initialData: fullSupplierData ?? _selectedSupplierData,
                                ),
                              );
                              if (result != null && mounted) {
                                setState(() {
                                  _selectedSupplierData = result;
                                  final code = (result['supplierCode'] ?? result['id'] ?? '').toString();
                                  final name = (result['name'] ?? result['companyName'] ?? '').toString();
                                  _selectedSupplierCodeAndName = "$code - $name";
                                  if (result['name'] != null) {
                                    _acNameController.text = result['name'].toString();
                                  }
                                  if (result['gstin'] != null && result['gstin'].toString().isNotEmpty) {
                                    _gstNumberController.text = result['gstin'].toString();
                                  }
                                  if (result['state'] != null) {
                                    _placeOfSupply = _standardizeState(result['state'].toString());
                                  }
                                  _loadSuppliers();
                                  _recalculateTotals();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: DropdownButtonFormField<String>(
                        initialValue: _placeOfSupply,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6D4C41)),
                        decoration: InputDecoration(
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF6D4C41))),
                        ),
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        items: {'Tamil Nadu', 'Kerala', 'Karnataka', 'Andhra Pradesh', _placeOfSupply}.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setState(() {
                            _placeOfSupply = newValue!;
                            _recalculateTotals();
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right Column of Top Section
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildTextField(
                "Voucher Date",
                isExpanded: true,
                controller: _voucherDateController,
                readOnly: true,
                onTap: () async {
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
                      _voucherDateController.text = DateFormat('dd/MM/yyyy EEE').format(picked);
                    });
                  }
                },
                suffixIcon: const Icon(Icons.calendar_month, size: 14, color: _brownLight),
              ),
              const SizedBox(height: 8),
              _buildDropdownWithLabel("Salesman", isExpanded: true, initialValue: _salesmanController.text, items: _salesmanOptions, onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _salesmanController.text = val;
                  });
                }
              }),
              const SizedBox(height: 8),
              _buildTextField(
                "Due Date",
                isExpanded: true,
                controller: _dueDateController,
                readOnly: true,
                onTap: () => _selectDate(context, _dueDateController),
                suffixIcon: const Icon(Icons.calendar_month, size: 14, color: _brownLight),
              ),
            ],
          ),
        ),
      ],
    );
  }



  void _setActiveRow(int index) {
    if (_activeRowIndex != index) {
      setState(() {
        _activeRowIndex = index;
      });
    }
  }

  Widget _buildTableHeader() {
    Color headerBg = const Color(0xFFF3EEDD); // Beige/grey header background
    return Row(
      children: [
        _buildGridCell(width: 30, backgroundColor: headerBg, child: const Center(child: Icon(Icons.arrow_right, size: 16, color: _brownLight))),
        _buildGridCell(width: 150, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Item Name", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Group", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Gross Wt.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Oth. Wt.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Net Wt.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 70, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Pcs.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 100, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Metal Rate", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 110, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Metal Amt.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 110, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Tot. Metal Amt.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 110, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Lab. On.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: headerBg, child: const Padding(padding: EdgeInsets.only(left: 6), child: Text("Lab. Per.", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
      ],
    );
  }

  Widget _buildTableRow(PurchaseBillingRow row, int index) {
    return Row(
      children: [
        _buildGridCell(
          width: 30,
          backgroundColor: const Color(0xFFFAF8F5),
          child: Center(
            child: _billingRows.length > 1
                ? InkWell(
                    onTap: () => _deleteBillingRow(index),
                    child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent),
                  )
                : const Icon(Icons.arrow_right, size: 16, color: _brownLight),
          ),
        ),
        _buildGridDropdown(
          width: 150,
          value: row.selectedItem,
          items: () {
            final opts = List<String>.from(_itemNameOptions);
            if (row.selectedItem.isNotEmpty && !opts.contains(row.selectedItem)) {
              opts.add(row.selectedItem);
            }
            return opts;
          }(),
          hint: "Item Name",
          onChanged: (val) {
            setState(() {
              row.selectedItem = val ?? '';
            });
            _setActiveRow(index);
            _onRowDataChanged();
          },
        ),
        _buildGridDropdown(
          width: 90,
          value: row.selectedGroup,
          items: _groupOptions,
          hint: "Group",
          onChanged: (val) {
            setState(() {
              row.selectedGroup = val;
              if (val != null) {
                double rate = _getRateForGroup(val);
                if (rate > 0) {
                  row.metalRateController.text = rate.toStringAsFixed(2);
                }
              }
            });
            _setActiveRow(index);
            _onRowDataChanged();
          },
        ),
        _buildGridTextField(
          controller: row.grossWtController,
          width: 90,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTap: () => _setActiveRow(index),
        ),
        _buildGridCheckbox(
          value: row.otherWtChecked,
          width: 90,
          onChanged: (val) {
            setState(() {
              row.otherWtChecked = val ?? false;
              if (row.otherWtChecked) {
                if (row.subRows.isEmpty) {
                  final newSub = PurchaseSubBillingRow();
                  newSub.weightController.addListener(_onRowDataChanged);
                  newSub.pcsController.addListener(_onRowDataChanged);
                  newSub.rateController.addListener(_onRowDataChanged);
                  newSub.labourPerController.addListener(_onRowDataChanged);
                  row.subRows.add(newSub);
                }
              } else {
                row.othWtController.text = '0.000';
                for (var sr in row.subRows) {
                  sr.dispose();
                }
                row.subRows.clear();
              }
            });
            _onRowDataChanged();
          },
        ),
        _buildGridTextField(
          controller: row.netWtController,
          width: 90,
          readOnly: !(row.otherWtChecked && row.netWtAccessible),
          focusNode: row.netWtFocus,
          onTap: () => _setActiveRow(index),
        ),
        _buildGridTextField(
          controller: row.pcsController,
          width: 70,
          keyboardType: TextInputType.number,
          onTap: () => _setActiveRow(index),
        ),
        _buildGridTextField(
          controller: row.metalRateController,
          width: 100,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTap: () => _setActiveRow(index),
        ),
        _buildGridCell(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              row.metalAmt.toStringAsFixed(2),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
            ),
          ),
        ),
        _buildGridCell(
          width: 110,
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              row.totMetalAmt.toStringAsFixed(2),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
            ),
          ),
        ),
        _buildGridDropdown(
          width: 110,
          value: row.labourOn,
          items: const [
            'Per Gram Gross Wt',
            'Per Gram Net Wt',
            'Per Gram Fine Wt',
            'Per Piece',
            'Percentage on Gross Wt',
            'Percentage on Net Wt',
            'Percentage on Fine Wt',
            'Fixed'
          ],
          onChanged: (val) {
            setState(() {
              row.labourOn = val ?? 'Per Gram Net Wt';
            });
            _setActiveRow(index);
            _onRowDataChanged();
          },
        ),
        _buildGridTextField(
          controller: row.labourPerController,
          width: 90,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onTap: () => _setActiveRow(index),
        ),
      ],
    );
  }

  Widget _buildSubRow(PurchaseBillingRow parentRow, PurchaseSubBillingRow subRow, int parentIndex, int subIndex) {
    return Container(
      color: const Color(0xFFFDFBF7),
      child: Row(
        children: [
          _buildGridCell(
            width: 180,
            backgroundColor: const Color(0xFFFDFBF7),
            child: Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                subIndex == 0 ? "↳ Other Wt. Style Name:" : "↳ Additional Style Name:",
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _brownLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          _buildGridCell(
            width: 90,
            backgroundColor: const Color(0xFFFDFBF7),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFFCA6F1E)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      final newSub = PurchaseSubBillingRow();
                      newSub.weightController.addListener(_onRowDataChanged);
                      newSub.pcsController.addListener(_onRowDataChanged);
                      newSub.rateController.addListener(_onRowDataChanged);
                      newSub.labourPerController.addListener(_onRowDataChanged);
                      parentRow.subRows.insert(subIndex + 1, newSub);
                    });
                    _onRowDataChanged();
                  },
                ),
                if (parentRow.subRows.length > 1) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 14, color: Colors.redAccent),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      setState(() {
                        final removed = parentRow.subRows.removeAt(subIndex);
                        removed.dispose();
                      });
                      _onRowDataChanged();
                    },
                  ),
                ],
              ],
            ),
          ),
          _buildGridDropdown(
            width: 90,
            value: subRow.styleName,
            items: _extraStyles,
            hint: "Style Name",
            onChanged: (val) {
              setState(() {
                subRow.styleName = val ?? 'Less Wt';
              });
              _onRowDataChanged();
            },
          ),
          _buildGridTextField(
            controller: subRow.weightController,
            width: 90,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => _setActiveRow(parentIndex),
          ),
          _buildGridCell(width: 90, backgroundColor: const Color(0xFFFDFBF7), child: const SizedBox.shrink()),
          _buildGridTextField(
            controller: subRow.pcsController,
            width: 70,
            keyboardType: TextInputType.number,
            onTap: () => _setActiveRow(parentIndex),
          ),
          _buildGridTextField(
            controller: subRow.rateController,
            width: 100,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => _setActiveRow(parentIndex),
          ),
          _buildGridCell(
            width: 110,
            backgroundColor: const Color(0xFFFDFBF7),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                subRow.metalAmt.toStringAsFixed(2),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
              ),
            ),
          ),
          _buildGridCell(
            width: 110,
            backgroundColor: const Color(0xFFFDFBF7),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                subRow.totMetalAmt.toStringAsFixed(2),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown),
              ),
            ),
          ),
          _buildGridDropdown(
            width: 110,
            value: subRow.labourOn,
            items: const [
              'Per Gram Gross Wt',
              'Per Gram Net Wt',
              'Per Gram Fine Wt',
              'Per Piece',
              'Percentage on Gross Wt',
              'Percentage on Net Wt',
              'Percentage on Fine Wt',
              'Fixed'
            ],
            onChanged: (val) {
              setState(() {
                subRow.labourOn = val ?? 'Per Piece';
              });
              _setActiveRow(parentIndex);
              _onRowDataChanged();
            },
          ),
          _buildGridTextField(
            controller: subRow.labourPerController,
            width: 90,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onTap: () => _setActiveRow(parentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRows() {
    final widgets = <Widget>[];
    for (int i = 0; i < _billingRows.length; i++) {
      final row = _billingRows[i];
      widgets.add(_buildTableRow(row, i));
      if (row.otherWtChecked) {
        for (int j = 0; j < row.subRows.length; j++) {
          widgets.add(_buildSubRow(row, row.subRows[j], i, j));
        }
      }
    }
    return Column(
      children: widgets,
    );
  }

  Widget _buildTableFooter() {
    double totalGrossWt = 0.0;
    double totalOthWt = 0.0;
    double totalNetWt = 0.0;
    int totalPcs = 0;
    double totalMetalAmt = 0.0;

    for (var row in _billingRows) {
      double grossWt = double.tryParse(row.grossWtController.text) ?? 0.0;
      double othWt = double.tryParse(row.othWtController.text) ?? 0.0;
      double netWt = grossWt - othWt;
      if (netWt < 0) netWt = 0.0;

      totalGrossWt += grossWt;
      totalOthWt += othWt;
      totalNetWt += netWt;
      totalPcs += int.tryParse(row.pcsController.text) ?? 0;
      totalMetalAmt += row.metalAmt;
    }

    Color footerBg = const Color(0xFFEEEEEE); // Light grey footer background
    return Row(
      children: [
        _buildGridCell(width: 30, backgroundColor: footerBg, child: const SizedBox.shrink()),
        _buildGridCell(width: 150, backgroundColor: footerBg, child: const SizedBox.shrink()),
        _buildGridCell(width: 90, backgroundColor: footerBg, child: const Center(child: Text("TOTAL", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: footerBg, child: Center(child: Text(totalGrossWt.toStringAsFixed(3), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: footerBg, child: Center(child: Text(totalOthWt.toStringAsFixed(3), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 90, backgroundColor: footerBg, child: Center(child: Text(totalNetWt.toStringAsFixed(3), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 70, backgroundColor: footerBg, child: Center(child: Text(totalPcs.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 100, backgroundColor: footerBg, child: const SizedBox.shrink()),
        _buildGridCell(width: 110, backgroundColor: footerBg, child: Center(child: Text(totalMetalAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 110, backgroundColor: footerBg, child: Center(child: Text(totalMetalAmt.toStringAsFixed(2), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)))),
        _buildGridCell(width: 110, backgroundColor: footerBg, child: const SizedBox.shrink()),
        _buildGridCell(width: 90, backgroundColor: footerBg, child: const SizedBox.shrink()),
      ],
    );
  }

  Widget _buildTableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                width: 1240,
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: _border),
                    left: BorderSide(color: _border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTableHeader(),
                    SizedBox(
                      height: 160, // Fixed height to prevent table shifting as rows are added
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: _buildTableRows(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 1240,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _addBillingRow,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text("Add Row", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                    ),
                    Text(
                      "Active Row: ${_activeRowIndex + 1} of ${_billingRows.length}",
                      style: const TextStyle(fontSize: 11, color: _brownLight, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 1240,
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: _border),
                    top: BorderSide(color: _border),
                  ),
                ),
                child: _buildTableFooter(),
              ),
            ],
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildBottomLeftSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Buttons
            SizedBox(
              width: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOutlineButton("Cash", isActive: _activeBottomPanel == 'Cash', onPressed: () => setState(() => _activeBottomPanel = 'Cash')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Bank", isActive: _activeBottomPanel == 'Bank', onPressed: () => setState(() => _activeBottomPanel = 'Bank')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Card", isActive: _activeBottomPanel == 'Card', onPressed: () => setState(() => _activeBottomPanel = 'Card')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("UPI", isActive: _activeBottomPanel == 'UPI', onPressed: () => setState(() => _activeBottomPanel = 'UPI')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Old Purchase", isActive: _activeBottomPanel == 'Old Purchase', onPressed: () => setState(() => _activeBottomPanel = 'Old Purchase')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Sales Return", isActive: _activeBottomPanel == 'Sales Return', onPressed: () => setState(() => _activeBottomPanel = 'Sales Return')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Gold Scheme", isActive: _activeBottomPanel == 'Gold Scheme', onPressed: () => setState(() => _activeBottomPanel = 'Gold Scheme')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Rate Apply", isActive: _activeBottomPanel == 'Rate Apply', onPressed: () => setState(() => _activeBottomPanel = 'Rate Apply')),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Dynamic Middle Area
            Expanded(
              child: _buildDynamicBottomPanel(),
            ),
            const SizedBox(width: 12),
            // Right Buttons
            SizedBox(
              width: 140,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildOutlineButton("Discount", isActive: _activeBottomPanel == 'Discount', onPressed: () => setState(() => _activeBottomPanel = 'Discount')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Extra Charge", isActive: _activeBottomPanel == 'Extra Charge', onPressed: () => setState(() => _activeBottomPanel = 'Extra Charge')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Narration", isActive: _activeBottomPanel == 'Narration', onPressed: () => setState(() => _activeBottomPanel = 'Narration')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Metal Settlement", isActive: _activeBottomPanel == 'Metal Settlement', onPressed: () => setState(() => _activeBottomPanel = 'Metal Settlement')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Type", isActive: _activeBottomPanel == 'Type', onPressed: () => setState(() => _activeBottomPanel = 'Type')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Metal Details", isActive: _activeBottomPanel == 'Metal Details', onPressed: () => setState(() => _activeBottomPanel = 'Metal Details')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("Rate Diff", isActive: _activeBottomPanel == 'Rate Diff', onPressed: () => setState(() => _activeBottomPanel = 'Rate Diff')),
                  const SizedBox(height: 4),
                  _buildOutlineButton("AP", isActive: _activeBottomPanel == 'AP', onPressed: () => setState(() => _activeBottomPanel = 'AP')),
                ],
              ),
            )
          ],
        ),
      ],
    );
  }

  Future<void> _fetchSalesReturnDetails() async {
    final invNo = _srOriginalInvController.text.trim();
    if (invNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter original invoice number')));
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bills')
          .where('voucherNo', isEqualTo: invNo)
          .get();
      if (!mounted) return;
      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No invoice found with this number')));
        return;
      }
      final docData = snap.docs.first.data();
      final itemsList = docData['items'] as List<dynamic>? ?? [];
      if (itemsList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items found in this invoice')));
        return;
      }
      final tagId = _srTagIdController.text.trim();
      Map<String, dynamic>? selectedItem;
      if (tagId.isNotEmpty) {
        for (var item in itemsList) {
          if (item is Map && item['tagId']?.toString().toLowerCase() == tagId.toLowerCase()) {
            selectedItem = Map<String, dynamic>.from(item);
            break;
          }
        }
      }
      if (selectedItem == null && itemsList.isNotEmpty) {
        selectedItem = Map<String, dynamic>.from(itemsList.first);
      }
      if (selectedItem != null) {
        setState(() {
          _srTagIdController.text = (selectedItem!['tagId'] ?? '').toString();
          _srGrossWtController.text = (selectedItem['grossWeight'] ?? selectedItem['grossWt'] ?? 0.0).toStringAsFixed(3);
          _srNetWtController.text = (selectedItem['netWeight'] ?? selectedItem['netWt'] ?? 0.0).toStringAsFixed(3);
          _srStoneWtController.text = (selectedItem['othWt'] ?? 0.0).toStringAsFixed(3);
          _srReturnRateController.text = (selectedItem['rate'] ?? 0.0).toStringAsFixed(2);
          _srDeductionsController.text = '0.00';
          
          double netWt = double.tryParse(_srNetWtController.text) ?? 0.0;
          double rate = double.tryParse(_srReturnRateController.text) ?? 0.0;
          double amt = netWt * rate;
          _salesReturnAmtController.text = amt.toStringAsFixed(2);
        });
        _recalculateTotals();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Details loaded for item: ${selectedItem['name'] ?? 'Gold Item'}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching sales return details: $e')));
    }
  }

  Future<void> _fetchGoldSchemeDetails() async {
    final acNo = _schemeAcNoController.text.trim();
    if (acNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Scheme A/C No')));
      return;
    }
    try {
      final docSnap = await FirebaseFirestore.instance.collection('gold_schemes').doc(acNo).get();
      if (!mounted) return;
      if (!docSnap.exists) {
        final q = await FirebaseFirestore.instance.collection('gold_schemes').where('schemeNo', isEqualTo: acNo).get();
        if (!mounted) return;
        if (q.docs.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No scheme found with this Account Number')));
          return;
        }
        _populateSchemeData(q.docs.first.data());
        return;
      }
      _populateSchemeData(docSnap.data()!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching Gold Scheme: $e')));
    }
  }

  void _populateSchemeData(Map<String, dynamic> data) {
    setState(() {
      _gsInstallmentsController.text = (data['installmentsPaid'] ?? data['installments'] ?? '0').toString();
      _gsBalanceController.text = (data['balance'] ?? data['schemeBalance'] ?? 0.0).toStringAsFixed(2);
      _gsBonusController.text = (data['bonus'] ?? data['benefit'] ?? 0.0).toStringAsFixed(2);
      
      double balance = double.tryParse(_gsBalanceController.text) ?? 0.0;
      double bonus = double.tryParse(_gsBonusController.text) ?? 0.0;
      _goldSchemeAmtController.text = (balance + bonus).toStringAsFixed(2);
    });
    _recalculateTotals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gold Scheme details loaded')));
    }
  }

  Future<void> _fetchAdvancePayment() async {
    final receiptNo = _apReceiptNoController.text.trim();
    if (receiptNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Receipt/Advance No')));
      return;
    }
    try {
      final q1 = await FirebaseFirestore.instance.collection('order_entries').where('voucherNo', isEqualTo: receiptNo).get();
      if (!mounted) return;
      if (q1.docs.isNotEmpty) {
        final data = q1.docs.first.data();
        setState(() {
          _apOriginalAmt = (data['advanceAmt'] ?? data['amount'] ?? 0.0).toDouble();
          _apAmtController.text = _apOriginalAmt.toStringAsFixed(2);
        });
        _recalculateTotals();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance loaded from Order Bookings')));
        return;
      }
      
      final q2 = await FirebaseFirestore.instance.collection('advance_payments').where('receiptNo', isEqualTo: receiptNo).get();
      if (!mounted) return;
      if (q2.docs.isNotEmpty) {
        final data = q2.docs.first.data();
        setState(() {
          _apOriginalAmt = (data['amount'] ?? data['advanceAmt'] ?? 0.0).toDouble();
          _apAmtController.text = _apOriginalAmt.toStringAsFixed(2);
        });
        _recalculateTotals();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Advance loaded successfully')));
        return;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No advance payment record found')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching advance: $e')));
    }
  }

  Widget _buildDynamicBottomPanel() {
    switch (_activeBottomPanel) {
      case 'Cash':
        return _buildCashPanel();
      case 'Bank':
        return _buildBankPanel();
      case 'Card':
        return _buildCardPanel();
      case 'UPI':
        return _buildUPIPanel();
      case 'Old Purchase':
        return _buildOldPurchasePanel();
      case 'Sales Return':
        return _buildGenericPanel("Sales Return Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Original Invoice No + Item Barcode / Tag ID
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 130, child: Text("Original Invoice No", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 120,
                    height: 28,
                    child: TextField(
                      controller: _srOriginalInvController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.search, color: _brown),
                    onPressed: _fetchSalesReturnDetails,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 130, child: Text("Item Barcode / Tag ID", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 200,
                    height: 28,
                    child: TextField(
                      controller: _srTagIdController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Gross Wt + Net Wt
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 130, child: Text("Gross Wt", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _srGrossWtController, readOnly: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 130, child: Text("Net Wt", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _srNetWtController, readOnly: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Stone Wt + Return Rate
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 130, child: Text("Stone Wt", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _srStoneWtController, readOnly: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 130, child: Text("Return Rate", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _srReturnRateController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: (val) {
                        double netWt = double.tryParse(_srNetWtController.text) ?? 0.0;
                        double rate = double.tryParse(val) ?? 0.0;
                        double deductions = double.tryParse(_srDeductionsController.text) ?? 0.0;
                        double amt = (netWt * rate) - deductions;
                        _salesReturnAmtController.text = amt > 0 ? amt.toStringAsFixed(2) : '0.00';
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 4: Deductions + Adjusted Amt
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 130, child: Text("Deductions", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _srDeductionsController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: (val) {
                        double netWt = double.tryParse(_srNetWtController.text) ?? 0.0;
                        double rate = double.tryParse(_srReturnRateController.text) ?? 0.0;
                        double deductions = double.tryParse(val) ?? 0.0;
                        double amt = (netWt * rate) - deductions;
                        _salesReturnAmtController.text = amt > 0 ? amt.toStringAsFixed(2) : '0.00';
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 130, child: Text("Adjusted Amt", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _salesReturnAmtController, readOnly: true,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 5: Update Button
              Row(
                children: [
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _salesReturnAmt = double.tryParse(_salesReturnAmtController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Gold Scheme':
        return _buildGenericPanel("Gold Scheme Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Scheme A/C No + Installments Paid
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 110, child: Text("Scheme A/C No", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _schemeAcNoController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.search, color: _brown),
                    onPressed: _fetchGoldSchemeDetails,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 110, child: Text("Installments Paid", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _gsInstallmentsController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Scheme Balance + Bonus/Benefit
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 110, child: Text("Scheme Balance", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _gsBalanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        double balance = double.tryParse(_gsBalanceController.text) ?? 0.0;
                        double bonus = double.tryParse(_gsBonusController.text) ?? 0.0;
                        _goldSchemeAmtController.text = (balance + bonus).toStringAsFixed(2);
                      },
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 110, child: Text("Bonus / Benefit", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _gsBonusController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        double balance = double.tryParse(_gsBalanceController.text) ?? 0.0;
                        double bonus = double.tryParse(_gsBonusController.text) ?? 0.0;
                        _goldSchemeAmtController.text = (balance + bonus).toStringAsFixed(2);
                      },
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 3: Redemption Amt + Update
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 110, child: Text("Redemption Amt", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _goldSchemeAmtController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _goldSchemeAmt = double.tryParse(_goldSchemeAmtController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Rate Apply':
        _dailyBoardRate = _getRateForGroup(_selectedRateType);
        return _buildGenericPanel("Rate Apply Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Rate Type + Custom Rate + Daily Board Rate
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 90, child: Text("Rate Type", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRateType,
                      icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: _groupOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedRateType = val;
                            _dailyBoardRate = _getRateForGroup(val);
                            _rateApplyController.text = _dailyBoardRate.toStringAsFixed(2);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 90, child: Text("Custom Rate", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _rateApplyController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text("Daily Board Rate: ${_dailyBoardRate.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _rateApplyAmt = double.tryParse(_rateApplyController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Discount':
        return _buildGenericPanel("Discount", [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildDiscountField("Voucher Amount", TextEditingController(text: _totalAmt.toStringAsFixed(2)), true),
                    _buildDiscountField("Discount %", _discountPerController, false, onChanged: (val) {
                      double per = double.tryParse(val) ?? 0.0;
                      double amt = _discountApplicableAmt * (per / 100);
                      if (_discountAmtController.text != amt.toStringAsFixed(2)) {
                        _discountAmtController.text = amt.toStringAsFixed(2);
                      }
                    }),
                    _buildDiscountField("Discount Amount", _discountAmtController, false, onChanged: (val) {
                      double amt = double.tryParse(val) ?? 0.0;
                      double per = _discountApplicableAmt > 0 ? (amt / _discountApplicableAmt) * 100 : 0.0;
                      if (_discountPerController.text != per.toStringAsFixed(2)) {
                        _discountPerController.text = per.toStringAsFixed(2);
                      }
                    }),
                    _buildDiscountField("Rounding Discount", _rndDiscountController, false),
                    _buildDiscountField("Final Voucher Amount", TextEditingController(text: _voucherAmt.toStringAsFixed(2)), true),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right column
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 100, child: Text("Discount Scheme", style: TextStyle(fontSize: 11, color: Colors.black87))),
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: DropdownButtonFormField<String>(
                              initialValue: "BILL WISE DISCOUNT",
                              icon: const Icon(Icons.arrow_drop_down, size: 16),
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                              ),
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              items: ["BILL WISE DISCOUNT", "ITEM WISE DISCOUNT"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const SizedBox(width: 100, child: Text("Discount Applied On", style: TextStyle(fontSize: 11, color: Colors.black87))),
                        Expanded(
                          child: SizedBox(
                            height: 24,
                            child: DropdownButtonFormField<String>(
                              initialValue: _discountCategory,
                              icon: const Icon(Icons.arrow_drop_down, size: 16),
                              decoration: InputDecoration(
                                fillColor: Colors.white,
                                filled: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                              ),
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                              items: ['On Bill Value', 'On Making Cost'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _discountCategory = val;
                                    double per = double.tryParse(_discountPerController.text) ?? 0.0;
                                    double amt = _discountApplicableAmt * (per / 100);
                                    _discountAmtController.text = amt.toStringAsFixed(2);
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildButton("Update", onPressed: () {
                      setState(() {
                        _discountAmt = double.tryParse(_discountAmtController.text) ?? 0.0;
                        _rndDiscount = double.tryParse(_rndDiscountController.text) ?? 0.0;
                      });
                      _recalculateTotals();
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("Adjust Amount with GST/VAT", style: TextStyle(fontSize: 11, color: Colors.black87)),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                height: 24,
                child: TextField(
                  controller: _adjustGstVatController,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    fillColor: Colors.white,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                    suffixIcon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                  ),
                ),
              )
            ],
          )
        ]);
      case 'Extra Charge':
        return _buildGenericPanel("Extra Charge Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTextField("Other Charge", width: 220, controller: _othChargeController),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _othCharge = double.tryParse(_othChargeController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Metal Settlement':
        return _buildGenericPanel("Metal Settlement Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Settlement Type + Settlement Weight
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 120, child: Text("Settlement Type", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: DropdownButtonFormField<String>(
                      initialValue: _msType,
                      icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: ['Fine Gold', 'Alloy Weight'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() { _msType = val; });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 120, child: Text("Settlement Weight", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _metalSettledWtController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Supplier Metal Account + Update
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 120, child: Text("Supplier Metal A/C", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 220,
                    height: 28,
                    child: TextField(
                      controller: _msAccountController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Type':
        return _buildGenericPanel("Invoice Type Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(width: 80, child: Text("Invoice Type", style: TextStyle(fontSize: 11, color: Colors.black87))),
                  SizedBox(
                    width: 160,
                    height: 24,
                    child: DropdownButtonFormField<String>(
                      initialValue: _invoiceType,
                      icon: const Icon(Icons.arrow_drop_down, size: 16),
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      items: ['Tax Invoice (GST)', 'Estimate (Rough Bill)', 'Chalk Memo', 'Delivery Challan'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _invoiceType = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 24),
                  const SizedBox(width: 80, child: Text("Tax Scheme", style: TextStyle(fontSize: 11, color: Colors.black87))),
                  SizedBox(
                    width: 160,
                    height: 24,
                    child: DropdownButtonFormField<String>(
                      initialValue: _taxScheme,
                      icon: const Icon(Icons.arrow_drop_down, size: 16),
                      decoration: InputDecoration(
                        fillColor: Colors.white,
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.black87),
                      items: ['CGST + SGST (Local)', 'IGST (Interstate)', 'No Tax'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _taxScheme = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTextField("Voucher Book Series", width: 180, controller: _voucherBookSeriesController),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Metal Details':
        final activeRow = _billingRows.isNotEmpty && _activeRowIndex < _billingRows.length ? _billingRows[_activeRowIndex] : null;
        return _buildGenericPanel("Active Row Metal Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info row
              Row(
                children: [
                  Text("Gross Wt: ${activeRow?.grossWtController.text ?? '0.000'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                  const SizedBox(width: 32),
                  Text("Net Wt: ${activeRow?.netWtController.text ?? '0.000'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                  const SizedBox(width: 32),
                  Text("Stone Wt: ${activeRow?.othWtController.text ?? '0.000'}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                ],
              ),
              const SizedBox(height: 12),
              // Row 1: Purity + Making Type
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 90, child: Text("Purity", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 130,
                    height: 28,
                    child: DropdownButtonFormField<String>(
                      initialValue: activeRow?.selectedGroup,
                      icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: _groupOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null && activeRow != null) {
                          setState(() {
                            activeRow.selectedGroup = val;
                            final rate = _getRateForGroup(val);
                            if (rate > 0) activeRow.metalRateController.text = rate.toStringAsFixed(2);
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 90, child: Text("Making Type", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 200,
                    height: 28,
                    child: DropdownButtonFormField<String>(
                      initialValue: activeRow?.labourOn,
                      icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      items: ['Per Gram Net Wt', 'Per Gram Gross Wt', 'Per Gram Fine Wt', 'Per Piece', 'Percentage', 'Percentage on Net Wt', 'Percentage on Gross Wt', 'Percentage on Fine Wt', 'Fixed'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        if (val != null && activeRow != null) {
                          setState(() { activeRow.labourOn = val; });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Rate/Val + Update
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 90, child: Text("Rate / Val", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  if (activeRow != null)
                    SizedBox(
                      width: 160,
                      height: 28,
                      child: TextField(
                        controller: activeRow.labourPerController,
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        decoration: InputDecoration(
                          fillColor: Colors.white, filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                        ),
                      ),
                    ),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    _onRowDataChanged();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Rate Diff':
        double totalNetWeight = _billingRows.fold(0.0, (acc, r) {
          final n = double.tryParse(r.netWtController.text) ?? 0.0;
          final pcs = double.tryParse(r.pcsController.text) ?? 1.0;
          return acc + n * pcs;
        });
        return _buildGenericPanel("Rate Difference Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Booked Rate + Current Rate + Difference
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 100, child: Text("Booked Rate", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _rdBookedRateController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: (val) {
                        double booked = double.tryParse(val) ?? 0.0;
                        double current = double.tryParse(_rdCurrentRateController.text) ?? 0.0;
                        double diff = current - booked;
                        double adjusted = diff * totalNetWeight;
                        _rateDiffController.text = adjusted.toStringAsFixed(2);
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 32),
                  SizedBox(width: 100, child: Text("Current Rate", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 140,
                    height: 28,
                    child: TextField(
                      controller: _rdCurrentRateController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      onChanged: (val) {
                        double booked = double.tryParse(_rdBookedRateController.text) ?? 0.0;
                        double current = double.tryParse(val) ?? 0.0;
                        double diff = current - booked;
                        double adjusted = diff * totalNetWeight;
                        _rateDiffController.text = adjusted.toStringAsFixed(2);
                      },
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text("Difference: ${((double.tryParse(_rdCurrentRateController.text) ?? 0.0) - (double.tryParse(_rdBookedRateController.text) ?? 0.0)).toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                ],
              ),
              const SizedBox(height: 12),
              // Row 2: Adjusted Value + Update
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 100, child: Text("Adjusted Value", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 160,
                    height: 28,
                    child: TextField(
                      controller: _rateDiffController,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                      decoration: InputDecoration(
                        fillColor: Colors.white, filled: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _rateDiffAmt = double.tryParse(_rateDiffController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'AP':
        double adjusted = double.tryParse(_apAmtController.text) ?? 0.0;
        double unadjusted = _apOriginalAmt - adjusted;
        return _buildGenericPanel("Advance Payment Details", [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTextField("Receipt No", width: 140, controller: _apReceiptNoController),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.search, color: _brown),
                    onPressed: _fetchAdvancePayment,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: _border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text("Original Advance: ${_apOriginalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTextField("Adjusted Amount", width: 140, controller: _apAmtController),
                  const SizedBox(width: 16),
                  Text("Unadjusted Balance: ${unadjusted.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red)),
                  const Spacer(),
                  _buildButton("Update", onPressed: () {
                    setState(() {
                      _apAmt = double.tryParse(_apAmtController.text) ?? 0.0;
                    });
                    _recalculateTotals();
                  }),
                ],
              ),
            ],
          )
        ]);
      case 'Narration':
      default:
        return _buildNarrationPanel();
    }
  }

  Widget _buildDiscountField(String label, TextEditingController controller, bool readOnly, {ValueChanged<String>? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87))),
          Expanded(
            child: SizedBox(
              height: 24,
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                onChanged: onChanged,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Colors.black87),
                decoration: InputDecoration(
                  fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: Colors.grey)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _brown)),
                  suffixIcon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericPanel(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(bottom: BorderSide(color: _border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Text(title, style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          )
        ],
      ),
    );
  }


  Widget _buildNarrationPanel() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(bottom: BorderSide(color: _border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: const Text("Narration", style: TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: TextField(
              controller: _narrationController,
              maxLines: 4,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOldPurchasePanel() {
    return _buildGenericPanel("Old Gold Purchase Details", [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Item Name + Purity
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 90, child: Text("Item Name", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 200,
                height: 28,
                child: TextField(
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              SizedBox(width: 90, child: Text("Purity", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 130,
                height: 28,
                child: DropdownButtonFormField<String>(
                  initialValue: _ogSelectedPurity,
                  icon: const Icon(Icons.arrow_drop_down, color: _brownLight, size: 18),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  items: _groupOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _ogSelectedPurity = val;
                        final rate = _getRateForGroup(val);
                        if (rate > 0) {
                          _ogRateController.text = rate.toStringAsFixed(2);
                        }
                      });
                      _calculateOldGoldAmount();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2: Gross Wt + Dust Wt
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 90, child: Text("Gross Wt.", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogGrossWtController,
                  onChanged: (_) => _calculateOldGoldAmount(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              SizedBox(width: 90, child: Text("Dust Wt.", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogDustWtController,
                  onChanged: (_) => _calculateOldGoldAmount(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 3: Net Wt + Wastage %
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 90, child: Text("Net Wt.", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogNetWtController, readOnly: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              SizedBox(width: 90, child: Text("Wastage %", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogWastageController,
                  onChanged: (_) => _calculateOldGoldAmount(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 4: Final Wt + Rate/gm
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 90, child: Text("Final Wt.", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogFinalWtController, readOnly: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              SizedBox(width: 90, child: Text("Rate/gm", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogRateController,
                  onChanged: (_) => _calculateOldGoldAmount(),
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 5: Amount + Add to Bill
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(width: 90, child: Text("Amount", style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 160,
                height: 28,
                child: TextField(
                  controller: _ogPurchaseController, readOnly: true,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  decoration: InputDecoration(
                    fillColor: Colors.white, filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
                  ),
                ),
              ),
              const Spacer(),
              _buildButton("Add to Bill", onPressed: () {
                setState(() {
                  _ogPurchaseAmt = double.tryParse(_ogPurchaseController.text) ?? 0.0;
                });
                _recalculateTotals();
              }),
            ],
          ),
        ],
      )
    ]);
  }



  Widget _buildCashPanel() {
    return _buildGenericPanel("Cash Receipt Details", [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTextField("Amount Received", width: 300, controller: _cashController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField("Remarks")),
              const SizedBox(width: 16),
              _buildButton("Update", onPressed: () {
                setState(() {
                  _cashAmt = double.tryParse(_cashController.text) ?? 0.0;
                });
                _recalculateTotals();
              }),
            ],
          ),
        ],
      )
    ]);
  }

  Widget _buildBankPanel() {
    return _buildGenericPanel("Bank Payment Details", [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 220,
                child: SizedBox(
                  height: 24,
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBankName,
                    icon: const Icon(Icons.arrow_drop_down, color: _brownLight),
                    decoration: const InputDecoration(
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        borderSide: BorderSide(color: _border),
                      ),
                    ),
                    hint: const Text('Select Bank', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                    items: _bankNamesList.map((name) {
                      return DropdownMenuItem<String>(value: name, child: Text(name));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedBankName = val),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildTextField("Cheque/Ref No.", width: 200, controller: _bankChequeController),
              const SizedBox(width: 16),
              _buildTextField("Amount", width: 180, controller: _bankController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField("Remarks", controller: _bankRemarksController)),
              const SizedBox(width: 16),
              _buildButton("Update", onPressed: () {
                setState(() {
                  _bankAmt = double.tryParse(_bankController.text) ?? 0.0;
                });
                _recalculateTotals();
              }),
            ],
          ),
        ],
      )
    ]);
  }

  Widget _buildCardPanel() {
    return _buildGenericPanel("Card Payment Details", [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTextField("Machine Name", width: 260, controller: _cardMachineController),
              const SizedBox(width: 16),
              _buildTextField("Card/Approval No.", width: 260, controller: _cardApprovalController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTextField("Amount", width: 300, controller: _cardController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField("Remarks", controller: _cardRemarksController)),
              const SizedBox(width: 16),
              _buildButton("Update", onPressed: () {
                setState(() {
                  _cardAmt = double.tryParse(_cardController.text) ?? 0.0;
                });
                _recalculateTotals();
              }),
            ],
          ),
        ],
      )
    ]);
  }

  Widget _buildUPIPanel() {
    return _buildGenericPanel("UPI Receipt Details", [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTextField("Transaction No / Ref No.", width: 500, controller: _upiRemarksController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildTextField("Amount", width: 500, controller: _upiController),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildTextField("Remarks", controller: _upiRemarks2Controller)),
              const SizedBox(width: 16),
              _buildButton("Update", onPressed: () {
                setState(() {
                  _upiAmt = double.tryParse(_upiController.text) ?? 0.0;
                });
                _recalculateTotals();
              }),
            ],
          ),
        ],
      )
    ]);
  }

  Widget _buildRightSidebar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_voucherNoPrefix == 'PR' ? "Debit" : "Credit", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_totalAmt.toStringAsFixed(2), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$_effectiveVoucherNoPrefix-${_voucherNoSuffixController.text}', style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.bold)),
            Text(DateFormat('dd/MM/yyyy EEE').format(DateTime.now()), style: const TextStyle(fontSize: 12, color: _brownLight, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        _buildSummaryCard("Voucher Details", {
          "Metal Amt": _metalAmt.toStringAsFixed(2),
          "Labour Amt": _labourAmt.toStringAsFixed(2),
          "Oth. Charge": _othCharge.toStringAsFixed(2),
          "Base Amt": _baseAmt.toStringAsFixed(2),
          "Discount Amt": _discountAmt.toStringAsFixed(2),
          "After Discount": _afterDiscount.toStringAsFixed(2),
          if (_placeOfSupply == 'Tamil Nadu') ...{
            "CGST Amount (1.5%)": _cgstAmt.toStringAsFixed(2),
            "SGST Amount (1.5%)": _sgstAmt.toStringAsFixed(2),
          } else ...{
            "IGST Amount (3%)": _igstAmt.toStringAsFixed(2),
          },
          "Total Amt": _totalAmt.toStringAsFixed(2),
          "Rnd. Discount": _rndDiscount.toStringAsFixed(2),
        }),
        _buildSummaryCard("Credit Details", {
          "Cash Amt": _cashAmt.toStringAsFixed(2),
          "Bank Amt": _bankAmt.toStringAsFixed(2),
          "Card Amt": _cardAmt.toStringAsFixed(2),
          "UPI Amt": _upiAmt.toStringAsFixed(2),
          "OG Purchase": _ogPurchaseAmt.toStringAsFixed(2),
        }),
        _buildSummaryCard("O/s. Details", {
          "Voucher Amt": _voucherAmt.toStringAsFixed(2),
          "Payment Amt": _paymentAmt.toStringAsFixed(2),
          "Due Amt": _dueAmt.toStringAsFixed(2),
          "Previous O/S": _previousOS.toStringAsFixed(2),
          "Final Due.": _finalDue.toStringAsFixed(2),
        }),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildActionButton(Icons.save, "Save", onPressed: _handleSave),
            const SizedBox(width: 16),
            _buildActionButton(Icons.print, "Print", onPressed: _handlePrint),
            const SizedBox(width: 16),
            _buildActionButton(Icons.close, "Close", onPressed: widget.onBack),
          ],
        )
      ],
    );
  }

  Widget _buildSummaryCard(String title, Map<String, String> details) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: _bg,
              border: Border(bottom: BorderSide(color: _border)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _brown)),
                const Icon(Icons.keyboard_arrow_up, size: 16, color: _brownLight),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: details.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 11, color: _brownLight)),
                    Text(e.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                  ],
                ),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, {VoidCallback? onPressed}) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: _brown),
          style: IconButton.styleFrom(
            backgroundColor: _bg,
            side: const BorderSide(color: _border),
          ),
          onPressed: onPressed ?? () {},
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _brown, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleSave() async {
    if (_isSaving) return;
    if (_acNameController.text.trim().isEmpty) {
      _showError("A/c. Name is required.");
      return;
    }
    if (_placeOfSupply.isEmpty) {
      _showError("State (Place of Supply) is required.");
      return;
    }

    bool hasValidRow = false;
    for (var row in _billingRows) {
      double netWt = double.tryParse(row.netWtController.text) ?? 0.0;
      double metalRate = double.tryParse(row.metalRateController.text) ?? 0.0;
      if (row.selectedItem.isNotEmpty && netWt > 0 && metalRate > 0) {
        hasValidRow = true;
        break;
      }
    }
    if (!hasValidRow) {
      _showError("At least one valid item row (Net Wt > 0, Metal Rate > 0) is required.");
      return;
    }

    setState(() {
      _isSaving = true;
    });


    try {
      DateTime parsedDate = DateTime.now();
      try {
        parsedDate = DateFormat('dd/MM/yyyy EEE').parse(_voucherDateController.text);
      } catch (_) {
        try {
          parsedDate = DateFormat('dd/MM/yyyy').parse(_voucherDateController.text);
        } catch (_) {}
      }

      bool isOnline = true;
      try {
        final connectivityResult = await Connectivity().checkConnectivity();
        if (connectivityResult.contains(ConnectivityResult.none)) {
          isOnline = false;
        } else {
          final res = await InternetAddress.lookup('google.com')
              .timeout(const Duration(milliseconds: 2500));
          if (res.isEmpty || res[0].rawAddress.isEmpty) {
            isOnline = false;
          }
        }
      } catch (e) {
        isOnline = false;
      }

      final String finalSuffix = _voucherNoSuffixController.text.trim();
      final String effectivePrefix = isOnline ? _voucherNoPrefix : '$_voucherNoPrefix-OFF';
      final voucherNo = '$effectivePrefix-$finalSuffix';
      // store voucherPrefix separately for easy filtering
      final voucherPrefix = effectivePrefix;

      final String caratValue = _billingRows.isNotEmpty && _billingRows[0].selectedGroup != null
          ? _billingRows[0].selectedGroup!
          : '';

      // Aggregate item details from all billing rows
      final String itemName = _billingRows
          .map((r) => r.selectedItem.trim())
          .where((s) => s.isNotEmpty)
          .join(', ');
      final double totalGrossWt = _billingRows.fold(0.0, (acc, r) {
        final g = double.tryParse(r.grossWtController.text) ?? 0.0;
        final pcs = double.tryParse(r.pcsController.text) ?? 1.0;
        return acc + g * pcs;
      });
      final double totalNetWt = _billingRows.fold(0.0, (acc, r) {
        final n = double.tryParse(r.netWtController.text) ?? 0.0;
        final pcs = double.tryParse(r.pcsController.text) ?? 1.0;
        return acc + n * pcs;
      });

      final List<Map<String, dynamic>> itemsList = _billingRows.map((r) {
        return {
          'tagId': r.labelNoController.text.trim(),
          'name': r.selectedItem.trim(),
          'productName': r.selectedItem.trim(),
          'group': r.selectedGroup ?? '',
          'purity': r.selectedGroup ?? '',
          'grossWeight': double.tryParse(r.grossWtController.text) ?? 0.0,
          'othWt': double.tryParse(r.othWtController.text) ?? 0.0,
          'netWeight': double.tryParse(r.netWtController.text) ?? 0.0,
          'pcs': int.tryParse(r.pcsController.text) ?? 1,
          'rate': double.tryParse(r.metalRateController.text) ?? 0.0,
          'metalAmt': r.metalAmt,
          'totMetalAmt': r.totMetalAmt,
          'labourOn': r.labourOn,
          'labourRate': double.tryParse(r.labourPerController.text) ?? 0.0,
          'labourAmt': r.labourAmt,
          'othWtChecked': r.otherWtChecked,
          'othWtStyle': r.subRows.isNotEmpty ? r.subRows.first.styleName : 'Less Wt',
          'extraCharges': r.otherWtChecked ? r.subRows.map((sr) {
            return {
              'styleName': sr.styleName,
              'weight': double.tryParse(sr.weightController.text) ?? 0.0,
              'pcs': int.tryParse(sr.pcsController.text) ?? 1,
              'rate': double.tryParse(sr.rateController.text) ?? 0.0,
              'amount': sr.totMetalAmt,
              'amtOn': (double.tryParse(sr.weightController.text) ?? 0.0) > 0 ? 'Weight' : 'Pcs',
              'labourRate': double.tryParse(sr.labourPerController.text) ?? 0.0,
              'labourOn': sr.labourOn,
              'labourAmt': sr.labourAmt,
            };
          }).toList() : [],
        };
      }).toList();

      final String? existingDocId = widget.initialData?['_docId']?.toString();
      final billData = {
        'voucherNo': voucherNo,
        'voucherPrefix': voucherPrefix,
        'carat': caratValue,
        'purity': caratValue,
        'billType': _voucherNoPrefix == 'PR' ? 'PurchaseReturn' : 'Purchase',
        'voucherDate': Timestamp.fromDate(parsedDate),
        'acName': _acNameController.text.trim(),
        'supplierDetails': _selectedSupplierData ?? {
          'name': _acNameController.text.trim(),
          'gstin': _gstNumberController.text.trim(),
        },
        'salesman': _salesmanController.text.trim(),
        'placeOfSupply': _placeOfSupply,
        'dueDate': _dueDateController.text.trim(),
        'itemName': itemName,
        'grossWeight': totalGrossWt,
        'netWeight': totalNetWt,
        'items': itemsList,
        'narration': _narrationController.text.trim(),
        'bankName': _selectedBankName ?? '',
        'bankChequeNo': _bankChequeController.text.trim(),
        'bankRemarks': _bankRemarksController.text.trim(),
        'cardMachine': _cardMachineController.text.trim(),
        'cardApprovalNo': _cardApprovalController.text.trim(),
        'cardRemarks': _cardRemarksController.text.trim(),
        'metalAmt': _metalAmt,
        'labourAmt': _labourAmt,
        'othCharge': _othCharge,
        'discountAmt': _discountAmt,
        'rndDiscount': _rndDiscount,
        'baseAmt': _baseAmt,
        'afterDiscount': _afterDiscount,
        'cgstAmt': _cgstAmt,
        'sgstAmt': _sgstAmt,
        'igstAmt': _igstAmt,
        'gstAmt': _gstAmt,
        'voucherAmt': _voucherAmt,
        'paymentAmt': _paymentAmt,
        'dueAmt': _dueAmt,
        'finalDue': _finalDue,
        'cashAmt': _cashAmt,
        'bankAmt': _bankAmt,
        'cardAmt': _cardAmt,
        'upiAmt': _upiAmt,
        'upiRefNo': _upiRemarksController.text.trim(),
        'upiRemarks': _upiRemarks2Controller.text.trim(),
        'ogPurchaseAmt': _ogPurchaseAmt,
        'ogGrossWt': double.tryParse(_ogGrossWtController.text) ?? 0.0,
        'ogDustWt': double.tryParse(_ogDustWtController.text) ?? 0.0,
        'ogNetWt': double.tryParse(_ogNetWtController.text) ?? 0.0,
        'ogWastage': double.tryParse(_ogWastageController.text) ?? 0.0,
        'ogFinalWt': double.tryParse(_ogFinalWtController.text) ?? 0.0,
        'ogRate': double.tryParse(_ogRateController.text) ?? 0.0,
        'salesReturnAmt': double.tryParse(_salesReturnAmtController.text) ?? 0.0,
        'schemeAcNo': _schemeAcNoController.text.trim(),
        'goldSchemeAmt': double.tryParse(_goldSchemeAmtController.text) ?? 0.0,
        'rateApplyAmt': double.tryParse(_rateApplyController.text) ?? 0.0,
        'metalSettledWt': double.tryParse(_metalSettledWtController.text) ?? 0.0,
        'rateDiffAmt': double.tryParse(_rateDiffController.text) ?? 0.0,
        'apAmt': double.tryParse(_apAmtController.text) ?? 0.0,
        // New bottom panels fields
        'srOriginalInvNo': _srOriginalInvController.text.trim(),
        'srTagId': _srTagIdController.text.trim(),
        'srGrossWt': double.tryParse(_srGrossWtController.text) ?? 0.0,
        'srNetWt': double.tryParse(_srNetWtController.text) ?? 0.0,
        'srStoneWt': double.tryParse(_srStoneWtController.text) ?? 0.0,
        'srReturnRate': double.tryParse(_srReturnRateController.text) ?? 0.0,
        'srDeductions': double.tryParse(_srDeductionsController.text) ?? 0.0,
        'gsInstallmentsPaid': int.tryParse(_gsInstallmentsController.text) ?? 0,
        'gsBalance': double.tryParse(_gsBalanceController.text) ?? 0.0,
        'gsBonus': double.tryParse(_gsBonusController.text) ?? 0.0,
        'msType': _msType,
        'msAccount': _msAccountController.text.trim(),
        'invoiceType': _invoiceType,
        'taxScheme': _taxScheme,
        'voucherBookSeries': _voucherBookSeriesController.text.trim(),
        'rdBookedRate': double.tryParse(_rdBookedRateController.text) ?? 0.0,
        'rdCurrentRate': double.tryParse(_rdCurrentRateController.text) ?? 0.0,
        'apReceiptNo': _apReceiptNoController.text.trim(),
        'apOriginalAmt': _apOriginalAmt,
        if (existingDocId == null) 'createdAt': FieldValue.serverTimestamp(),
        if (existingDocId != null) 'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingDocId != null) {
        await FirebaseFirestore.instance.collection('bills').doc(existingDocId).update(billData);
      } else {
        final connectivityResult = await Connectivity().checkConnectivity();
        final bool isOnline = connectivityResult.contains(ConnectivityResult.wifi) || connectivityResult.contains(ConnectivityResult.mobile);
        
        if (isOnline) {
          await FirebaseFirestore.instance.collection('bills').add(billData);
        } else {
          // Append -OFF to the voucher string explicitly
          if (!voucherNo.endsWith('-OFF')) {
            billData['voucherNo'] = '$voucherNo-OFF';
          }
          await LocalDbService().insertEntry('bills', billData, operation: 'ADD');
          SyncService().syncNow();
        }
      }

      // Success SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Bill ${billData['voucherNo']} saved successfully!'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }

      if (widget.onBack != null) {
        if (!mounted) return;
        Navigator.pop(context, {
          'voucherNo': voucherNo,
          'voucherDate': DateFormat('dd/MM/yyyy EEE').format(parsedDate),
          'accountName': _acNameController.text.trim(),
          'voucherType': 'Purchase',
          'totalAmount': _totalAmt.toStringAsFixed(2),
          'bookName': 'Purchase',
          'reference': '',
          'refNo': '',
          'date': DateFormat('dd/MM/yyyy').format(DateTime.now()),
          'memoVoucher': 'No',
          'narration': _narrationController.text.trim(),
        });
        return;
      }

      // Fetch next voucher number and clear inputs
      await _fetchNextVoucherNumber();
      setState(() {
        _cashController.clear();
        _bankController.clear();
        _cardController.clear();
        _upiController.clear();
        _upiRemarksController.clear();
        _upiRemarks2Controller.clear();
        _ogPurchaseController.clear();
        _salesReturnAmtController.clear();
        _schemeAcNoController.clear();
        _goldSchemeAmtController.clear();
        _rateApplyController.clear();
        _metalSettledWtController.clear();
        _rateDiffController.clear();
        _apAmtController.clear();
        _othChargeController.clear();
        _discountAmtController.clear();
        _dueDateController.clear();
        _bankChequeController.clear();
        _bankRemarksController.clear();
        _cardMachineController.clear();
        _cardApprovalController.clear();
        _cardRemarksController.clear();
        _narrationController.clear();

        _cashAmt = 0.0;
        _bankAmt = 0.0;
        _cardAmt = 0.0;
        _upiAmt = 0.0;

        // Clear new controllers
        _srOriginalInvController.clear();
        _srTagIdController.clear();
        _srGrossWtController.clear();
        _srNetWtController.clear();
        _srStoneWtController.clear();
        _srReturnRateController.clear();
        _srDeductionsController.clear();
        _gsInstallmentsController.clear();
        _gsBalanceController.clear();
        _gsBonusController.clear();
        _msAccountController.clear();
        _voucherBookSeriesController.clear();
        _rdBookedRateController.clear();
        _rdCurrentRateController.clear();
        _apReceiptNoController.clear();
        _selectedSupplierData = null;
        _billingRows.clear();
      });
      _addBillingRow();

    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Failed to save bill: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  void _handlePrint() {
    try {
      double totalDiaAmt = 0.0;
      double totalOtherChgAmt = 0.0;
      final invoiceItems = _billingRows.map((row) {
        final name = row.selectedItem.isEmpty ? "Gold Ornament" : row.selectedItem;
        final pcs = int.tryParse(row.pcsController.text) ?? 1;
        final gross = double.tryParse(row.grossWtController.text) ?? 0.0;
        final net = double.tryParse(row.netWtController.text) ?? 0.0;
        final rate = double.tryParse(row.metalRateController.text) ?? 0.0;

        double diaAmt = 0.0;
        double otherChgAmt = 0.0;
        if (row.otherWtChecked) {
          for (var sr in row.subRows) {
            final style = sr.styleName.trim().toLowerCase();
            if (style == 'diamond') {
              diaAmt += sr.metalAmt;
            } else {
              otherChgAmt += sr.metalAmt;
            }
          }
        }
        totalDiaAmt += diaAmt;
        totalOtherChgAmt += otherChgAmt;

        final baseMetalAmt = row.metalAmt - diaAmt - otherChgAmt;

        final double labourRate = double.tryParse(row.labourPerController.text) ?? 0.0;
        final String labourOn = row.labourOn;
        
        String labourRateStr = '';
        if (labourRate > 0) {
          if (labourOn.toLowerCase().contains('gram') || labourOn.toLowerCase().contains('g')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} /G';
          } else if (labourOn.toLowerCase().contains('percent') || labourOn.contains('%')) {
            labourRateStr = '${labourRate.toStringAsFixed(2)} %';
          } else {
            labourRateStr = '${labourRate.toStringAsFixed(2)} Fx';
          }
        }

        return InvoiceItem(
          description: name,
          pcs: pcs,
          purity: row.selectedGroup ?? '22K',
          grossWt: gross,
          netWt: net,
          rate: rate,
          metalAmount: baseMetalAmt,
          diaAmount: diaAmt,
          labour: row.labourAmt,
          colStAndOtChg: otherChgAmt,
          amount: row.metalAmt + row.labourAmt,
          labourAmount: row.labourAmt,
          labourRateStr: labourRateStr,
        );
      }).toList();

      final gross = _totalAmt - _rndDiscount;
      
      final List<String> receiptParts = [];
      if (_cashAmt > 0) receiptParts.add('Cash: ${_cashAmt.toStringAsFixed(2)}');
      if (_bankAmt > 0) {
        String bankStr = 'Bank: ${_bankAmt.toStringAsFixed(2)}';
        if (_bankChequeController.text.isNotEmpty) bankStr += ' (Chq: ${_bankChequeController.text})';
        if (_bankRemarksController.text.isNotEmpty) bankStr += ' (${_bankRemarksController.text})';
        receiptParts.add(bankStr);
      }
      if (_cardAmt > 0) {
        String cardStr = 'Card: ${_cardAmt.toStringAsFixed(2)}';
        if (_cardMachineController.text.isNotEmpty) cardStr += ' (Mch: ${_cardMachineController.text})';
        if (_cardApprovalController.text.isNotEmpty) cardStr += ' (App: ${_cardApprovalController.text})';
        receiptParts.add(cardStr);
      }
      if (_upiAmt > 0) {
        String upiStr = 'UPI: ${_upiAmt.toStringAsFixed(2)}';
        if (_upiRemarksController.text.isNotEmpty) upiStr += ' (${_upiRemarksController.text})';
        if (_upiRemarks2Controller.text.isNotEmpty) upiStr += ' (${_upiRemarks2Controller.text})';
        receiptParts.add(upiStr);
      }
      if (_goldSchemeAmt > 0) {
        String schemeStr = 'Scheme: ${_goldSchemeAmt.toStringAsFixed(2)}';
        if (_schemeAcNoController.text.isNotEmpty) schemeStr += ' (A/c: ${_schemeAcNoController.text})';
        receiptParts.add(schemeStr);
      }
      if (_ogPurchaseAmt > 0) {
        String ogStr = 'Old Gold: ${_ogPurchaseAmt.toStringAsFixed(2)}';
        if (_ogGrossWtController.text.isNotEmpty) ogStr += ' (${_ogGrossWtController.text}g @ ${_ogRateController.text})';
        receiptParts.add(ogStr);
      }
      if (_salesReturnAmt > 0) {
        String srStr = 'Sales Return: ${_salesReturnAmt.toStringAsFixed(2)}';
        if (_srOriginalInvController.text.isNotEmpty) srStr += ' (Inv: ${_srOriginalInvController.text})';
        receiptParts.add(srStr);
      }
      if (_apAmt > 0) {
        receiptParts.add('Advance Pay: ${_apAmt.toStringAsFixed(2)}');
      }
      if (_rateApplyAmt > 0) {
        receiptParts.add('Rate Fix: ${_rateApplyAmt.toStringAsFixed(2)}');
      }
      final receiptDetailsText = receiptParts.isEmpty ? '0.00' : receiptParts.join('\n');
      final creditsText = _dueAmt > 0 ? 'Credit Sale: ${_dueAmt.toStringAsFixed(2)}' : '0.00';

      final invoiceData = SalesInvoiceData(
        customerName: _acNameController.text.isEmpty ? 'Walk-in Supplier' : _acNameController.text.trim(),
        customerMobile: _selectedSupplierData?['phone']?.toString() ?? _selectedSupplierData?['mobile']?.toString() ?? '',
        customerAddress: _selectedSupplierData?['address']?.toString() ?? _selectedSupplierData?['city']?.toString() ?? 'COIMBATORE, Tamil Nadu',
        customerState: _selectedSupplierData?['state']?.toString() ?? 'Tamil Nadu - 33',
        invoiceNo: '$_effectiveVoucherNoPrefix-${_voucherNoSuffixController.text}',
        date: _voucherDateController.text.trim(),
        placeOfSupply: _placeOfSupply,
        items: invoiceItems,
        totalPcs: _billingRows.fold(0.0, (acc, r) => acc + (double.tryParse(r.pcsController.text) ?? 0)),
        totalGrossWt: _billingRows.fold(0.0, (acc, r) => acc + (double.tryParse(r.grossWtController.text) ?? 0)),
        totalNetWt: _billingRows.fold(0.0, (acc, r) => acc + (double.tryParse(r.netWtController.text) ?? 0)),
        totalMetalAmt: _metalAmt - totalDiaAmt - totalOtherChgAmt,
        totalAmount: _afterDiscount,
        discountAmt: _discountAmt,
        taxableAmount: _afterDiscount,
        cgstAmt: _gstAmt / 2,
        sgstAmt: _gstAmt / 2,
        igstAmt: _placeOfSupply == 'Tamil Nadu' ? 0.0 : _gstAmt,
        roundOff: _rndDiscount > 0 ? -_rndDiscount : 0,
        grossAmount: gross,
        receivedAmt: _paymentAmt,
        amountInWords: PdfInvoiceApi.numberToWords(gross),
        cardDetails: _cardAmt > 0 ? _cardAmt.toStringAsFixed(2) : "0.00",
        customerPan: _selectedSupplierData?['pan']?.toString() ?? _selectedSupplierData?['panNumber']?.toString() ?? _selectedSupplierData?['panNo']?.toString() ?? '',
        narration: _narrationController.text.trim(),
        dueAmount: _dueAmt,
        receiptDetails: receiptDetailsText,
        credits: creditsText,
      );

      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 850,
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF3E2723),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Purchase Print Preview - ${invoiceData.invoiceNo}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PdfPreview(
                    build: (format) => PdfInvoiceApi.generate(invoiceData),
                    allowSharing: false,
                    allowPrinting: true,
                    actions: [
                      PdfPreviewAction(
                        icon: const Icon(Icons.share_rounded, color: Colors.white),
                        onPressed: (context, buildPdf, pageFormat) async {
                          await shareInvoiceHelper(context: context, invoiceData: invoiceData);
                        },
                      ),
                    ],
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    dynamicLayout: false,
                    canDebug: false,
                    initialPageFormat: PdfPageFormat.a4,
                    pdfFileName: 'Purchase_${invoiceData.invoiceNo}.pdf',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

}

class PurchaseSubBillingRow {
  String styleName = 'Less Wt';
  final TextEditingController weightController = TextEditingController();
  final TextEditingController pcsController = TextEditingController();
  final TextEditingController rateController = TextEditingController();
  final TextEditingController labourPerController = TextEditingController();
  String labourOn = 'Per Piece';
  double metalAmt = 0.0;
  double totMetalAmt = 0.0;
  double labourAmt = 0.0;

  PurchaseSubBillingRow() {
    weightController.text = '0.000';
    pcsController.text = '1';
    rateController.text = '0.00';
    labourPerController.text = '0.00';
  }

  void dispose() {
    weightController.dispose();
    pcsController.dispose();
    rateController.dispose();
    labourPerController.dispose();
  }
}

class PurchaseBillingRow {
  String selectedItem = '';
  final TextEditingController labelNoController = TextEditingController();
  String? selectedGroup;
  final TextEditingController grossWtController = TextEditingController();
  final TextEditingController othWtController = TextEditingController();
  final TextEditingController netWtController = TextEditingController();
  final TextEditingController pcsController = TextEditingController();
  final TextEditingController metalRateController = TextEditingController();
  double metalAmt = 0.0;
  double totMetalAmt = 0.0;
  String labourOn = 'Per Gram Net Wt';
  final TextEditingController labourPerController = TextEditingController();
  double labourAmt = 0.0;
  bool requireOtherWt = false;
  bool netWtAccessible = false;
  final FocusNode netWtFocus = FocusNode();
  bool otherWtChecked = false;
  String otherWtStyle = 'Less Wt';

  final List<PurchaseSubBillingRow> subRows = [];

  PurchaseBillingRow() {
    grossWtController.text = '0.000';
    othWtController.text = '0.000';
    netWtController.text = '0.000';
    pcsController.text = '1';
    metalRateController.text = '0.00';
    labourPerController.text = '0.00';
    otherWtChecked = false;
    otherWtStyle = 'Less Wt';
  }

  void dispose() {
    labelNoController.dispose();
    grossWtController.dispose();
    othWtController.dispose();
    netWtController.dispose();
    pcsController.dispose();
    metalRateController.dispose();
    labourPerController.dispose();
    netWtFocus.dispose();
    for (var sr in subRows) {
      sr.dispose();
    }
  }
}
