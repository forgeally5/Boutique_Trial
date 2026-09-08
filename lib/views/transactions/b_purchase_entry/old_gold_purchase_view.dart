import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io' show File, Directory;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../../../products/viewmodels/old_gold_purchase_viewmodel.dart';
import '../../../models/old_gold_purchase.dart';
import '../../../state/admin_state.dart';
import '../../widgets/connection_status_badge.dart';
import '../../../auth/viewmodels/auth_viewmodel.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _brownBg = Color(0xFFFAF7F2);
const _gold = Color(0xFFCA6F1E);
const _border = Color(0xFFE5DDD0);

class OldGoldPurchaseView extends StatefulWidget {
  const OldGoldPurchaseView({super.key});

  @override
  State<OldGoldPurchaseView> createState() => _OldGoldPurchaseViewState();
}

class _OldGoldPurchaseViewState extends State<OldGoldPurchaseView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _acNameController;
  late TextEditingController _salesmanController;
  late TextEditingController _placeOfSupplyController;
  late TextEditingController _dueDateDaysController;

  late TextEditingController _otherChargesController;
  late TextEditingController _discountAmtController;
  late TextEditingController _rndDiscountController;

  late TextEditingController _cashAmtController;
  late TextEditingController _bankAmtController;
  late TextEditingController _cardAmtController;
  late TextEditingController _ogPurchaseController;
  late TextEditingController _previousOSController;

  // Main Form Sidebar Focus Nodes
  late FocusNode _otherChargesFocus;
  late FocusNode _discountAmtFocus;
  late FocusNode _rndDiscountFocus;
  late FocusNode _cashAmtFocus;
  late FocusNode _bankAmtFocus;
  late FocusNode _cardAmtFocus;
  late FocusNode _ogPurchaseFocus;
  late FocusNode _previousOSFocus;

  @override
  void initState() {
    super.initState();
    _acNameController = TextEditingController();
    _salesmanController = TextEditingController();
    _placeOfSupplyController = TextEditingController();
    _dueDateDaysController = TextEditingController(text: '0');

    _otherChargesController = TextEditingController(text: '0.00');
    _discountAmtController = TextEditingController(text: '0.00');
    _rndDiscountController = TextEditingController(text: '0.00');

    _cashAmtController = TextEditingController(text: '0.00');
    _bankAmtController = TextEditingController(text: '0.00');
    _cardAmtController = TextEditingController(text: '0.00');
    _ogPurchaseController = TextEditingController(text: '0.00');
    _previousOSController = TextEditingController(text: '0.00');

    // Initialize Sidebar Focus Nodes
    _otherChargesFocus = FocusNode();
    _discountAmtFocus = FocusNode();
    _rndDiscountFocus = FocusNode();
    _cashAmtFocus = FocusNode();
    _bankAmtFocus = FocusNode();
    _cardAmtFocus = FocusNode();
    _ogPurchaseFocus = FocusNode();
    _previousOSFocus = FocusNode();

    _setupMainFocusListener(_otherChargesFocus, _otherChargesController);
    _setupMainFocusListener(_discountAmtFocus, _discountAmtController);
    _setupMainFocusListener(_rndDiscountFocus, _rndDiscountController);
    _setupMainFocusListener(_cashAmtFocus, _cashAmtController);
    _setupMainFocusListener(_bankAmtFocus, _bankAmtController);
    _setupMainFocusListener(_cardAmtFocus, _cardAmtController);
    _setupMainFocusListener(_ogPurchaseFocus, _ogPurchaseController);
    _setupMainFocusListener(_previousOSFocus, _previousOSController);
  }

  void _setupMainFocusListener(FocusNode node, TextEditingController controller) {
    node.addListener(() {
      final vm = Provider.of<OldGoldPurchaseViewModel>(context, listen: false);
      if (node.hasFocus) {
        final text = controller.text.trim();
        if (text == '0.00' || text == '0') {
          controller.clear();
        }
      } else {
        if (controller.text.trim().isEmpty) {
          controller.text = '0.00';
          _triggerFinancialRecalc(vm);
        }
      }
    });
  }

  @override
  void dispose() {
    _acNameController.dispose();
    _salesmanController.dispose();
    _placeOfSupplyController.dispose();
    _dueDateDaysController.dispose();
    _otherChargesController.dispose();
    _discountAmtController.dispose();
    _rndDiscountController.dispose();
    _cashAmtController.dispose();
    _bankAmtController.dispose();
    _cardAmtController.dispose();
    _ogPurchaseController.dispose();
    _previousOSController.dispose();

    // Dispose Sidebar Focus Nodes
    _otherChargesFocus.dispose();
    _discountAmtFocus.dispose();
    _rndDiscountFocus.dispose();
    _cashAmtFocus.dispose();
    _bankAmtFocus.dispose();
    _cardAmtFocus.dispose();
    _ogPurchaseFocus.dispose();
    _previousOSFocus.dispose();
    super.dispose();
  }

  void _triggerFinancialRecalc(OldGoldPurchaseViewModel vm) {
    vm.updateFinancials(
      otherCharges: double.tryParse(_otherChargesController.text) ?? 0.0,
      discountAmt: double.tryParse(_discountAmtController.text) ?? 0.0,
      rndDiscount: double.tryParse(_rndDiscountController.text) ?? 0.0,
      cashAmt: double.tryParse(_cashAmtController.text) ?? 0.0,
      bankAmt: double.tryParse(_bankAmtController.text) ?? 0.0,
      cardAmt: double.tryParse(_cardAmtController.text) ?? 0.0,
      ogPurchase: double.tryParse(_ogPurchaseController.text) ?? 0.0,
      previousOS: double.tryParse(_previousOSController.text) ?? 0.0,
    );
  }

  void _openAddItemDialog(BuildContext context, OldGoldPurchaseViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => _OldGoldAddItemDialog(vm: vm),
    );
  }

  void _openHistoryDialog(BuildContext context, OldGoldPurchaseViewModel vm) {
    vm.fetchHistory();
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider<OldGoldPurchaseViewModel>.value(
        value: vm,
        child: const _OldGoldHistoryDialog(),
      ),
    );
  }

  Future<void> _submitVoucher(OldGoldPurchaseViewModel vm) async {
    if (!_formKey.currentState!.validate()) return;

    final adminEmail = context.read<AuthViewModel>().adminUser?.email ?? '';

    // Push inputs to VM
    vm.updateHeader(
      acName: _acNameController.text.trim(),
      salesman: _salesmanController.text.trim(),
      placeOfSupply: _placeOfSupplyController.text.trim(),
      dueDateDays: int.tryParse(_dueDateDaysController.text) ?? 0,
    );
    _triggerFinancialRecalc(vm);

    // Capture the voucher data before reset
    final savedVoucher = OldGoldPurchase(
      voucherNo: vm.voucherNo,
      bookName: vm.bookName,
      acName: _acNameController.text.trim(),
      salesman: _salesmanController.text.trim(),
      placeOfSupply: _placeOfSupplyController.text.trim(),
      voucherDate: vm.voucherDate,
      dueDateDays: int.tryParse(_dueDateDaysController.text) ?? 0,
      dueDate: vm.dueDate,
      items: List.from(vm.items),
      metalAmtTotal: vm.metalAmtTotal,
      labourAmtTotal: vm.labourAmtTotal,
      otherCharges: vm.otherCharges,
      discountAmt: vm.discountAmt,
      totalAmt: vm.totalAmt,
      rndDiscount: vm.rndDiscount,
      cashAmt: double.tryParse(_cashAmtController.text) ?? 0.0,
      bankAmt: double.tryParse(_bankAmtController.text) ?? 0.0,
      cardAmt: double.tryParse(_cardAmtController.text) ?? 0.0,
      ogPurchase: double.tryParse(_ogPurchaseController.text) ?? 0.0,
      voucherAmt: vm.voucherAmt,
      paymentAmt: vm.paymentAmt,
      dueAmt: vm.dueAmt,
      previousOS: vm.previousOS,
      finalDue: vm.finalDue,
      createdBy: adminEmail,
    );

    await vm.saveVoucher(adminEmail);

    if (!mounted) return;

    if (vm.status == OldGoldSaveStatus.success) {
      final actualVoucher = OldGoldPurchase(
        voucherNo: vm.voucherNo,
        bookName: savedVoucher.bookName,
        acName: savedVoucher.acName,
        salesman: savedVoucher.salesman,
        placeOfSupply: savedVoucher.placeOfSupply,
        voucherDate: savedVoucher.voucherDate,
        dueDateDays: savedVoucher.dueDateDays,
        dueDate: savedVoucher.dueDate,
        items: savedVoucher.items,
        metalAmtTotal: savedVoucher.metalAmtTotal,
        labourAmtTotal: savedVoucher.labourAmtTotal,
        otherCharges: savedVoucher.otherCharges,
        discountAmt: savedVoucher.discountAmt,
        totalAmt: savedVoucher.totalAmt,
        rndDiscount: savedVoucher.rndDiscount,
        cashAmt: savedVoucher.cashAmt,
        bankAmt: savedVoucher.bankAmt,
        cardAmt: savedVoucher.cardAmt,
        ogPurchase: savedVoucher.ogPurchase,
        voucherAmt: savedVoucher.voucherAmt,
        paymentAmt: savedVoucher.paymentAmt,
        dueAmt: savedVoucher.dueAmt,
        previousOS: savedVoucher.previousOS,
        finalDue: savedVoucher.finalDue,
        createdBy: savedVoucher.createdBy,
        voucherType: 'Purchase',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('URD Purchase saved successfully! Voucher No: ${actualVoucher.voucherNo}'),
          backgroundColor: Colors.green,
        ),
      );
      _showPrintPreviewDialog(context, actualVoucher);
      _resetAll(vm);
    } else if (vm.status == OldGoldSaveStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving voucher: ${vm.errorMessage}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _resetAll(OldGoldPurchaseViewModel vm) {
    vm.reset();
    _acNameController.clear();
    _salesmanController.clear();
    _placeOfSupplyController.clear();
    _dueDateDaysController.text = '0';
    _otherChargesController.text = '0.00';
    _discountAmtController.text = '0.00';
    _rndDiscountController.text = '0.00';
    _cashAmtController.text = '0.00';
    _bankAmtController.text = '0.00';
    _cardAmtController.text = '0.00';
    _ogPurchaseController.text = '0.00';
    _previousOSController.text = '0.00';
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<OldGoldPurchaseViewModel>(
      create: (_) {
        final vm = OldGoldPurchaseViewModel();
        vm.fetchNextVoucherNo();
        return vm;
      },
      child: Consumer<OldGoldPurchaseViewModel>(
        builder: (context, vm, child) {
          return Scaffold(
            backgroundColor: _brownBg,
            body: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── LEFT COLUMN (Voucher Header & Main Grid) ───────────────────
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        // Header Form Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.fromLTRB(24, 24, 12, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'OLD GOLD PURCHASE [EURD]',
                                        style: TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: _brown,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      ConnectionStatusBadge(state: Provider.of<AdminState>(context, listen: false)),
                                      const SizedBox(width: 16),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: _brownLight,
                                          side: const BorderSide(color: _border),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _openHistoryDialog(context, vm),
                                        icon: const Icon(Icons.history, size: 16),
                                        label: const Text('View History', style: TextStyle(fontSize: 11)),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Voucher No: ${vm.voucherNo.isEmpty ? "Generating..." : vm.voucherNo}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _gold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(color: _border, height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'A/C NAME *',
                                      controller: _acNameController,
                                      hint: 'e.g. John Doe',
                                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'BOOK NAME',
                                      controller: TextEditingController(text: vm.bookName),
                                      enabled: false,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'SALESMAN',
                                      controller: _salesmanController,
                                      hint: 'e.g. Salesman 1',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDateDisplay(
                                      label: 'VOUCHER DATE',
                                      date: vm.voucherDate,
                                      onTap: () async {
                                        final DateTime? picked = await showDatePicker(
                                          context: context,
                                          initialDate: vm.voucherDate,
                                          firstDate: DateTime(2000),
                                          lastDate: DateTime(2101),
                                        );
                                        if (picked != null) {
                                          vm.updateHeader(voucherDate: picked);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'DUE DATE (DAYS)',
                                      controller: _dueDateDaysController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (val) {
                                        final days = int.tryParse(val) ?? 0;
                                        vm.updateHeader(dueDateDays: days);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildTextField(
                                      label: 'PLACE OF SUPPLY',
                                      controller: _placeOfSupplyController,
                                      hint: 'e.g. Tamil Nadu',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Table Grid Card
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(24, 0, 12, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'PURCHASE ITEMS LIST',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _brown,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _gold,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                        ),
                                        onPressed: () => _openAddItemDialog(context, vm),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Row'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: _border, height: 1),
                                Expanded(
                                  child: _buildGridTable(vm),
                                ),
                                const Divider(color: _border, height: 1),
                                // Totals Row Display
                                _buildTableTotalsBar(vm),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ─── RIGHT COLUMN (Sidebar Breakdown & Calculations) ─────────────
                  Expanded(
                    flex: 3,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 24, 24, 24),
                      child: Column(
                        children: [
                          // Calculations Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSidebarHeader('Voucher Details (Debit)'),
                                const SizedBox(height: 12),
                                _buildSidebarAmtRow('Metal Amt', vm.metalAmtTotal),
                                _buildSidebarAmtRow('Labour Amt', vm.labourAmtTotal),
                                const SizedBox(height: 8),
                                _buildSidebarField('Other Charges (₹)', _otherChargesController, vm, focusNode: _otherChargesFocus),
                                _buildSidebarField('Discount Amt (₹)', _discountAmtController, vm, focusNode: _discountAmtFocus),
                                _buildSidebarField('Rnd Discount (₹)', _rndDiscountController, vm, focusNode: _rndDiscountFocus),
                                const Divider(color: _border, height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, color: _brown)),
                                    Text('₹ ${vm.totalAmt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: _gold, fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                _buildSidebarHeader('Payment Details (Credit)'),
                                const SizedBox(height: 12),
                                _buildSidebarField('Cash Amt (₹)', _cashAmtController, vm, focusNode: _cashAmtFocus),
                                _buildSidebarField('Bank Amt (₹)', _bankAmtController, vm, focusNode: _bankAmtFocus),
                                _buildSidebarField('Card Amt (₹)', _cardAmtController, vm, focusNode: _cardAmtFocus),
                                _buildSidebarField('OG Purchase Adjust (₹)', _ogPurchaseController, vm, focusNode: _ogPurchaseFocus),
                                const SizedBox(height: 20),

                                _buildSidebarHeader('Outstanding Details'),
                                const SizedBox(height: 12),
                                _buildSidebarAmtRow('Voucher Amt', vm.voucherAmt),
                                _buildSidebarAmtRow('Payment Amt', vm.paymentAmt),
                                _buildSidebarAmtRow('Due Amt', vm.dueAmt),
                                _buildSidebarField('Previous O/S (₹)', _previousOSController, vm, focusNode: _previousOSFocus),
                                const Divider(color: _border, height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Final Due', style: TextStyle(fontWeight: FontWeight.bold, color: _brown)),
                                    Text('₹ ${vm.finalDue.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: _gold, fontSize: 16)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Actions buttons Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _brown,
                                    side: const BorderSide(color: _border),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                  onPressed: () => _resetAll(vm),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _brown,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  ),
                                  onPressed: vm.isSaving ? null : () => _submitVoucher(vm),
                                  child: vm.isSaving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Text('Save (F2)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
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
          );
        },
      ),
    );
  }

  // Helper Form fields
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _brownLight),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: _brown, fontSize: 12),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 11),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: enabled ? Colors.white : const Color(0xFFF0EBE0),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _brown, width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateDisplay({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _brownLight),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(6),
              color: Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd/MM/yyyy (EEE)').format(date),
                  style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Icon(Icons.calendar_month, size: 16, color: _brownLight),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(width: 24, height: 2, color: _gold),
      ],
    );
  }

  Widget _buildSidebarAmtRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _brownLight, fontSize: 12)),
          Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(color: _brown, fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSidebarField(String label, TextEditingController controller, OldGoldPurchaseViewModel vm, {FocusNode? focusNode}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: _brownLight, fontSize: 12)),
          ),
          SizedBox(
            width: 110,
            height: 32,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
              onChanged: (_) => _triggerFinancialRecalc(vm),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _border),
                  borderRadius: BorderRadius.circular(4),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _brown, width: 1.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Custom Data Grid
  Widget _buildGridTable(OldGoldPurchaseViewModel vm) {
    if (vm.items.isEmpty) {
      return const Center(
        child: Text(
          'No items added yet. Click "Add Row" to start.',
          style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
        ),
      );
    }

    return ListView.separated(
      itemCount: vm.items.length,
      separatorBuilder: (context, index) => const Divider(color: _border, height: 1),
      itemBuilder: (context, index) {
        final item = vm.items[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _brown)),
                    const SizedBox(height: 2),
                    Text('Label: ${item.labelNo.isEmpty ? "None" : item.labelNo} | Group: ${item.group}', style: const TextStyle(fontSize: 10, color: _brownLight)),
                  ],
                ),
              ),
              Expanded(
                child: _tableValCol('Gross Wt', '${item.grossWt.toStringAsFixed(3)} g'),
              ),
              Expanded(
                child: _tableValCol('Net Wt', '${item.netWt.toStringAsFixed(3)} g'),
              ),
              Expanded(
                child: _tableValCol('Purity', '${item.purity}%'),
              ),
              Expanded(
                child: _tableValCol('Fine Wt', '${item.fineWt.toStringAsFixed(3)} g'),
              ),
              Expanded(
                child: _tableValCol('Metal Value', '₹${item.metalAmount.toStringAsFixed(2)}'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                onPressed: () => vm.removeItemAt(index),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tableValCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _brownLight, fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: _brown, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildTableTotalsBar(OldGoldPurchaseViewModel vm) {
    return Container(
      color: const Color(0xFFF5EFE6),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTALS:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown),
          ),
          _totalsLabel('Gross: ${vm.grossWtTotal.toStringAsFixed(3)}g'),
          _totalsLabel('Net: ${vm.netWtTotal.toStringAsFixed(3)}g'),
          _totalsLabel('Fine: ${vm.fineWtTotal.toStringAsFixed(3)}g'),
          _totalsLabel('Pcs: ${vm.pcsTotal}'),
          _totalsLabel('Metal Value: ₹${vm.metalAmtTotal.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _totalsLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Item Dialog (Modal Popup)
// ─────────────────────────────────────────────────────────────────────────────
class _OldGoldAddItemDialog extends StatefulWidget {
  final OldGoldPurchaseViewModel vm;

  const _OldGoldAddItemDialog({required this.vm});

  @override
  State<_OldGoldAddItemDialog> createState() => _OldGoldAddItemDialogState();
}

class _OldGoldAddItemDialogState extends State<_OldGoldAddItemDialog> {
  final _rowFormKey = GlobalKey<FormState>();

  late TextEditingController _itemNameCtrl;
  late TextEditingController _labelNoCtrl;
  late TextEditingController _groupCtrl;

  late TextEditingController _grossWtCtrl;
  late TextEditingController _stoneWtCtrl;
  late TextEditingController _otherWtCtrl;
  late TextEditingController _urdLessWtCtrl;
  late TextEditingController _purityCtrl;
  late TextEditingController _pcsCtrl;
  late TextEditingController _metalRateCtrl;
  late TextEditingController _labourRateCtrl;

  bool _othReq = false;

  // Dialog Focus Nodes
  late FocusNode _grossWtFocus;
  late FocusNode _stoneWtFocus;
  late FocusNode _otherWtFocus;
  late FocusNode _urdLessWtFocus;
  late FocusNode _purityFocus;
  late FocusNode _pcsFocus;
  late FocusNode _metalRateFocus;
  late FocusNode _labourRateFocus;

  @override
  void initState() {
    super.initState();
    _itemNameCtrl = TextEditingController();
    _labelNoCtrl = TextEditingController();
    _groupCtrl = TextEditingController(text: 'Old Gold');

    _grossWtCtrl = TextEditingController(text: '0.000');
    _stoneWtCtrl = TextEditingController(text: '0.000');
    _otherWtCtrl = TextEditingController(text: '0.000');
    _urdLessWtCtrl = TextEditingController(text: '0.000');

    _otherWtCtrl.addListener(() {
      final parsed = double.tryParse(_otherWtCtrl.text) ?? 0.0;
      if (parsed > 0.0) {
        if (!_othReq) {
          setState(() {
            _othReq = true;
          });
        }
      } else {
        if (_othReq) {
          setState(() {
            _othReq = false;
          });
        }
      }
    });
    _purityCtrl = TextEditingController(text: '91.6');
    _pcsCtrl = TextEditingController(text: '1');
    _metalRateCtrl = TextEditingController(text: '0.00');
    _labourRateCtrl = TextEditingController(text: '0.00');

    // Initialize Dialog Focus Nodes
    _grossWtFocus = FocusNode();
    _stoneWtFocus = FocusNode();
    _otherWtFocus = FocusNode();
    _urdLessWtFocus = FocusNode();
    _purityFocus = FocusNode();
    _pcsFocus = FocusNode();
    _metalRateFocus = FocusNode();
    _labourRateFocus = FocusNode();

    _setupDialogFocusListener(_grossWtFocus, _grossWtCtrl, 'Wt');
    _setupDialogFocusListener(_stoneWtFocus, _stoneWtCtrl, 'Wt');
    _setupDialogFocusListener(_otherWtFocus, _otherWtCtrl, 'Wt');
    _setupDialogFocusListener(_urdLessWtFocus, _urdLessWtCtrl, 'Wt');
    _setupDialogFocusListener(_purityFocus, _purityCtrl, 'Purity');
    _setupDialogFocusListener(_pcsFocus, _pcsCtrl, 'Pieces');
    _setupDialogFocusListener(_metalRateFocus, _metalRateCtrl, 'Rate');
    _setupDialogFocusListener(_labourRateFocus, _labourRateCtrl, 'Rate');
  }

  void _setupDialogFocusListener(FocusNode node, TextEditingController controller, String type) {
    node.addListener(() {
      if (node.hasFocus) {
        final text = controller.text.trim();
        if (text == '0.000' || text == '0.00' || text == '0' || text == '1' || text == '91.6') {
          controller.clear();
        }
      } else {
        if (controller.text.trim().isEmpty) {
          if (type == 'Wt') {
            controller.text = '0.000';
          } else if (type == 'Rate') {
            controller.text = '0.00';
          } else if (type == 'Pieces') {
            controller.text = '1';
          } else if (type == 'Purity') {
            controller.text = '91.6';
          } else {
            controller.text = '0';
          }
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _itemNameCtrl.dispose();
    _labelNoCtrl.dispose();
    _groupCtrl.dispose();
    _grossWtCtrl.dispose();
    _stoneWtCtrl.dispose();
    _otherWtCtrl.dispose();
    _urdLessWtCtrl.dispose();
    _purityCtrl.dispose();
    _pcsCtrl.dispose();
    _metalRateCtrl.dispose();
    _labourRateCtrl.dispose();

    // Dispose Dialog Focus Nodes
    _grossWtFocus.dispose();
    _stoneWtFocus.dispose();
    _otherWtFocus.dispose();
    _urdLessWtFocus.dispose();
    _purityFocus.dispose();
    _pcsFocus.dispose();
    _metalRateFocus.dispose();
    _labourRateFocus.dispose();
    super.dispose();
  }

  // Real-time getters for computed dialog weights/amounts
  double get gross => double.tryParse(_grossWtCtrl.text) ?? 0.0;
  double get stone => double.tryParse(_stoneWtCtrl.text) ?? 0.0;
  double get other => double.tryParse(_otherWtCtrl.text) ?? 0.0;
  double get less => double.tryParse(_urdLessWtCtrl.text) ?? 0.0;
  double get net {
    final computed = gross - stone - other;
    return computed < 0 ? 0.0 : computed;
  }
  double get effective => (net - less) < 0 ? 0.0 : (net - less);
  double get purity => double.tryParse(_purityCtrl.text) ?? 0.0;
  double get fine => effective * (purity / 100);
  int get pcs => int.tryParse(_pcsCtrl.text) ?? 1;
  double get rate => double.tryParse(_metalRateCtrl.text) ?? 0.0;
  double get metalAmt => fine * rate;
  double get labourRate => double.tryParse(_labourRateCtrl.text) ?? 0.0;
  double get labourAmt => net * labourRate; // Calculated Per Gram Net Wt by default

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: _brownBg,
      child: Container(
        width: 650,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _rowFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Old Gold Purchase Item',
                  style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: _brown),
                ),
                const Divider(color: _border, height: 20),

                // Name & group row
                Row(
                  children: [
                    Expanded(
                      child: _buildInput('Item Name *', _itemNameCtrl, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput('Group', _groupCtrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Weights inputs
                Row(
                  children: [
                    Expanded(
                      child: _buildInput('Gross Wt (g) *', _grossWtCtrl, focusNode: _grossWtFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput('Stone Wt (g)', _stoneWtCtrl, focusNode: _stoneWtFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput('Other Wt (g)', _otherWtCtrl, focusNode: _otherWtFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Calculated Net Wt & URD Less Wt
                Row(
                  children: [
                    Expanded(
                      child: _buildCalculatedField('Net Wt (g) [Calculated]', net.toStringAsFixed(3)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput('URD Less Wt (g)', _urdLessWtCtrl, focusNode: _urdLessWtFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCalculatedField('Effective Wt (g) [Calculated]', effective.toStringAsFixed(3)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Purity, pieces, and rate
                Row(
                  children: [
                    Expanded(
                      child: _buildInput('Purity (%)', _purityCtrl, focusNode: _purityFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCalculatedField('Fine Wt (g) [Calculated]', fine.toStringAsFixed(3)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInput('Pieces (Pcs)', _pcsCtrl, focusNode: _pcsFocus, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildInput('Metal Rate (₹/g) *', _metalRateCtrl, focusNode: _metalRateFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCalculatedField('Metal Amount (₹)', metalAmt.toStringAsFixed(2)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildInput('Labour Rate (₹/g)', _labourRateCtrl, focusNode: _labourRateFocus, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCalculatedField('Labour Amount (₹)', labourAmt.toStringAsFixed(2)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Checkbox(
                      value: _othReq,
                      activeColor: _gold,
                      onChanged: (val) {
                        setState(() {
                          _othReq = val ?? false;
                        });
                      },
                    ),
                    const Text('Other Wt Required (Oth. Req.)', style: TextStyle(color: _brownLight, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: _brown),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.white),
                      onPressed: () {
                        if (!_rowFormKey.currentState!.validate()) return;
                        final item = OldGoldPurchaseItem(
                          itemName: _itemNameCtrl.text.trim(),
                          labelNo: _labelNoCtrl.text.trim(),
                          group: _groupCtrl.text.trim(),
                          grossWt: gross,
                          othReq: _othReq,
                          netWt: net,
                          purity: purity,
                          fineWt: fine,
                          pcs: pcs,
                          metalRate: rate,
                          metalAmount: metalAmt,
                          labourRate: labourRate,
                          labourAmount: labourAmt,
                          urdLessWt: less,
                        );
                        widget.vm.addItem(item);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Add Item'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _brownLight)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: _brown, fontSize: 12),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _border),
              borderRadius: BorderRadius.circular(6),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: _brown, width: 1.2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCalculatedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: _brownLight)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0EBE0),
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY DIALOG — Displays all saved URD Purchase vouchers from Firestore
// ═══════════════════════════════════════════════════════════════════════════════

class _OldGoldHistoryDialog extends StatefulWidget {
  const _OldGoldHistoryDialog();

  @override
  State<_OldGoldHistoryDialog> createState() => _OldGoldHistoryDialogState();
}

class _OldGoldHistoryDialogState extends State<_OldGoldHistoryDialog> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OldGoldPurchaseViewModel>(
      builder: (context, vm, child) {
        final filteredHistory = vm.history.where((v) {
          final query = _searchQuery.trim().toLowerCase();
          if (query.isEmpty) return true;
          return v.voucherNo.toLowerCase().contains(query) ||
              v.acName.toLowerCase().contains(query) ||
              v.salesman.toLowerCase().contains(query);
        }).toList();

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: _brownBg,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.82,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📋 Saved URD Purchase Vouchers',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _brownLight,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          ),
                          onPressed: () => vm.fetchHistory(),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.close, color: _brownLight, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _searchQuery.isEmpty
                      ? 'Total: ${vm.history.length} voucher(s)'
                      : 'Found: ${filteredHistory.length} of ${vm.history.length} voucher(s)',
                  style: const TextStyle(color: _brownLight, fontSize: 11),
                ),
                const SizedBox(height: 8),

                // Search Bar
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: const TextStyle(fontSize: 13, color: _brown),
                    decoration: InputDecoration(
                      hintText: 'Search by Voucher No, A/C Name, Salesman...',
                      hintStyle: const TextStyle(fontSize: 12, color: _brownLight),
                      prefixIcon: const Icon(Icons.search, size: 18, color: _brownLight),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: _brownLight),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _gold, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const Divider(color: _border, height: 20),

                // Content
                Expanded(
                  child: vm.isLoadingHistory
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: _gold),
                              SizedBox(height: 12),
                              Text('Loading vouchers...', style: TextStyle(color: _brownLight, fontSize: 12)),
                            ],
                          ),
                        )
                      : filteredHistory.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.receipt_long, size: 48, color: _border),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? 'No URD Purchase vouchers saved yet.'
                                        : 'No vouchers match your search.',
                                    style: const TextStyle(color: _brownLight, fontSize: 13, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            )
                          : Scrollbar(
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: constraints.maxWidth,
                                        ),
                                        child: DataTable(
                                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0EBE0)),
                                          dataRowMinHeight: 40,
                                          dataRowMaxHeight: 56,
                                          columnSpacing: 18,
                                          horizontalMargin: 12,
                                          headingTextStyle: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: _brown,
                                            letterSpacing: 0.3,
                                          ),
                                          dataTextStyle: const TextStyle(
                                            fontSize: 11,
                                            color: _brownLight,
                                          ),
                                          columns: const [
                                            DataColumn(label: Text('Voucher No')),
                                            DataColumn(label: Text('Date')),
                                            DataColumn(label: Text('A/C Name')),
                                            DataColumn(label: Text('Salesman')),
                                            DataColumn(label: Text('Items')),
                                            DataColumn(label: Text('Gross Wt'), numeric: true),
                                            DataColumn(label: Text('Net Wt'), numeric: true),
                                            DataColumn(label: Text('Fine Wt'), numeric: true),
                                            DataColumn(label: Text('Metal Amt'), numeric: true),
                                            DataColumn(label: Text('Total Amt'), numeric: true),
                                            DataColumn(label: Text('Payment'), numeric: true),
                                            DataColumn(label: Text('Due'), numeric: true),
                                            DataColumn(label: Text('Actions')),
                                          ],
                                          rows: filteredHistory.map((v) {
                                             final isReceipt = v.voucherType == 'Receipt';
                                             final grossWt = v.items.fold(0.0, (acc, i) => acc + i.grossWt);
                                             final netWt = v.items.fold(0.0, (acc, i) => acc + i.netWt);
                                             final fineWt = v.items.fold(0.0, (acc, i) => acc + i.fineWt);
                                             return DataRow(
                                               cells: [
                                                 DataCell(Column(
                                                   mainAxisAlignment: MainAxisAlignment.center,
                                                   crossAxisAlignment: CrossAxisAlignment.start,
                                                   children: [
                                                     Text(
                                                       v.voucherNo,
                                                       style: const TextStyle(fontWeight: FontWeight.bold, color: _gold),
                                                     ),
                                                     if (isReceipt)
                                                       Container(
                                                         margin: const EdgeInsets.only(top: 2),
                                                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                         decoration: BoxDecoration(
                                                           color: Colors.green.shade50,
                                                           border: Border.all(color: Colors.green.shade200),
                                                           borderRadius: BorderRadius.circular(4),
                                                         ),
                                                         child: Text(
                                                           'Receipt (Ref: ${v.parentVoucherNo ?? ""})',
                                                           style: TextStyle(
                                                             fontSize: 9,
                                                             fontWeight: FontWeight.bold,
                                                             color: Colors.green.shade700,
                                                           ),
                                                         ),
                                                       ),
                                                   ],
                                                 )),
                                                 DataCell(Text(DateFormat('dd/MM/yyyy').format(v.voucherDate))),
                                                 DataCell(
                                                   ConstrainedBox(
                                                     constraints: const BoxConstraints(maxWidth: 120),
                                                     child: Text(v.acName, overflow: TextOverflow.ellipsis),
                                                   ),
                                                 ),
                                                 DataCell(Text(v.salesman.isEmpty ? '—' : v.salesman)),
                                                 DataCell(Text('${v.items.length}')),
                                                 DataCell(Text(isReceipt ? '—' : '${grossWt.toStringAsFixed(3)}g')),
                                                 DataCell(Text(isReceipt ? '—' : '${netWt.toStringAsFixed(3)}g')),
                                                 DataCell(Text(isReceipt ? '—' : '${fineWt.toStringAsFixed(3)}g')),
                                                 DataCell(Text(isReceipt ? '—' : '₹${v.metalAmtTotal.toStringAsFixed(2)}')),
                                                 DataCell(Text(
                                                   '₹${v.totalAmt.toStringAsFixed(2)}',
                                                   style: const TextStyle(fontWeight: FontWeight.bold, color: _brown),
                                                 )),
                                                 DataCell(Text('₹${v.paymentAmt.toStringAsFixed(2)}')),
                                                 DataCell(Text(
                                                   '₹${v.finalDue.toStringAsFixed(2)}',
                                                   style: TextStyle(
                                                     fontWeight: FontWeight.bold,
                                                     color: v.finalDue > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                                   ),
                                                 )),
                                                 DataCell(
                                                   Row(
                                                     mainAxisSize: MainAxisSize.min,
                                                     children: [
                                                       IconButton(
                                                         icon: const Icon(Icons.print_outlined, size: 18, color: _brownLight),
                                                         tooltip: 'Print Bill',
                                                         onPressed: () => _showPrintPreviewDialog(context, v),
                                                       ),
                                                       const SizedBox(width: 4),
                                                       if (!isReceipt && v.finalDue > 0) ...[
                                                         IconButton(
                                                           icon: const Icon(Icons.account_balance_wallet_outlined, size: 18, color: _gold),
                                                           tooltip: 'Receive Payment',
                                                           onPressed: () => _showPaymentUpdateDialog(context, vm, v),
                                                         ),
                                                         const SizedBox(width: 4),
                                                       ],
                                                       IconButton(
                                                         icon: Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                                                         tooltip: 'Delete voucher',
                                                         onPressed: () async {
                                                           final confirm = await showDialog<bool>(
                                                             context: context,
                                                             builder: (ctx) => AlertDialog(
                                                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                               title: const Text('Delete Voucher?', style: TextStyle(fontFamily: 'serif', color: _brown, fontSize: 16)),
                                                               content: Text('Are you sure you want to delete ${v.voucherNo}?'),
                                                               actions: [
                                                                 TextButton(
                                                                   onPressed: () => Navigator.of(ctx).pop(false),
                                                                   child: const Text('Cancel', style: TextStyle(color: _brownLight)),
                                                                 ),
                                                                 ElevatedButton(
                                                                   style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                                                                   onPressed: () => Navigator.of(ctx).pop(true),
                                                                   child: const Text('Delete'),
                                                                 ),
                                                               ],
                                                             ),
                                                           );
                                                           if (confirm == true) {
                                                             await vm.deleteVoucher(v.voucherNo);
                                                           }
                                                         },
                                                       ),
                                                     ],
                                                   ),
                                                 ),
                                               ],
                                             );
                                           }).toList(),
                                        ),
                                      ),
                                    );
                                  },
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

  Future<void> _showPaymentUpdateDialog(BuildContext context, OldGoldPurchaseViewModel vm, OldGoldPurchase v) async {
    final TextEditingController amountController = TextEditingController();
    String selectedMode = 'Cash';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Receive Payment — ${v.voucherNo}',
                style: const TextStyle(fontFamily: 'serif', color: _brown, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('A/C Name: ${v.acName}', style: const TextStyle(color: _brownLight, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Total Amount: ₹${v.totalAmt.toStringAsFixed(2)}', style: const TextStyle(color: _brownLight, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Current Due: ₹${v.finalDue.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 14, color: _brown),
                    decoration: const InputDecoration(
                      labelText: 'Payment Amount (₹)',
                      hintText: 'Enter amount',
                      labelStyle: TextStyle(color: _brownLight, fontSize: 12),
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _gold, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: _gold,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        amountController.text = v.finalDue.toStringAsFixed(2);
                      },
                      child: Text(
                        'Pay Full Amount (₹${v.finalDue.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Payment Mode', style: TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMode,
                    style: const TextStyle(fontSize: 13, color: _brown),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Cash', 'Bank', 'Card', 'OG Purchase'].map((mode) {
                      return DropdownMenuItem<String>(
                        value: mode,
                        child: Text(mode),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedMode = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: _brownLight)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () async {
                    final amt = double.tryParse(amountController.text) ?? 0.0;
                    if (amt <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount'), backgroundColor: Colors.redAccent),
                      );
                      return;
                    }

                    try {
                      final adminEmail = context.read<AuthViewModel>().adminUser?.email ?? '';
                      final receipt = await vm.updateVoucherPayment(v.voucherNo, amt, selectedMode, adminEmail);
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment of ₹${amt.toStringAsFixed(2)} updated successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (receipt != null) {
                          _showPrintPreviewDialog(context, receipt);
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating payment: $e'), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

void _printVoucher(BuildContext context, OldGoldPurchase v) async {
    final isReceipt = v.voucherType == 'Receipt';
    final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(v.voucherDate);

    // Generate Items Rows HTML
    String itemsHtml = '';
    if (!isReceipt) {
      for (int i = 0; i < v.items.length; i++) {
        final item = v.items[i];
        itemsHtml += '''
          <tr>
            <td>${i + 1}</td>
            <td>${item.itemName} (${item.group})</td>
            <td>${item.purity.toStringAsFixed(1)}%</td>
            <td align="right">${item.grossWt.toStringAsFixed(3)}g</td>
            <td align="right">${item.netWt.toStringAsFixed(3)}g</td>
            <td align="right">${item.fineWt.toStringAsFixed(3)}g</td>
            <td align="right">₹${item.metalRate.toStringAsFixed(2)}</td>
            <td align="right">₹${item.metalAmount.toStringAsFixed(2)}</td>
            <td align="right">₹${item.labourAmount.toStringAsFixed(2)}</td>
            <td align="right">₹${(item.metalAmount + item.labourAmount).toStringAsFixed(2)}</td>
          </tr>
        ''';
      }
    }

    // Generate HTML Content
    final String htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>${isReceipt ? 'Receipt' : 'Invoice'} - ${v.voucherNo}</title>
  <style>
    body {
      font-family: 'Courier New', Courier, monospace;
      font-size: 12px;
      color: #333;
      margin: 20px;
      padding: 0;
    }
    .receipt-container {
      max-width: 800px;
      margin: 0 auto;
      border: 1px solid #ddd;
      padding: 20px;
      background-color: #fff;
    }
    .header {
      text-align: center;
      margin-bottom: 20px;
    }
    .shop-name {
      font-size: 24px;
      font-weight: bold;
      color: #3E2723;
      letter-spacing: 1px;
    }
    .shop-info {
      font-size: 11px;
      color: #666;
      margin-top: 5px;
    }
    .receipt-title {
      font-size: 16px;
      font-weight: bold;
      text-align: center;
      margin: 15px 0;
      text-transform: uppercase;
      text-decoration: underline;
      color: #CA6F1E;
    }
    .meta-table, .totals-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 15px;
    }
    .meta-table td {
      padding: 4px 0;
      vertical-align: top;
    }
    .items-table {
      width: 100%;
      border-collapse: collapse;
      margin: 15px 0;
    }
    .items-table th {
      border-top: 1px dashed #333;
      border-bottom: 1px dashed #333;
      padding: 8px 4px;
      font-weight: bold;
      text-align: left;
    }
    .items-table td {
      padding: 6px 4px;
      border-bottom: 1px dashed #eee;
    }
    .divider {
      border-top: 1px dashed #333;
      margin: 10px 0;
    }
    .double-divider {
      border-top: 3px double #333;
      margin: 10px 0;
    }
    .text-right {
      text-align: right;
    }
    .bold {
      font-weight: bold;
    }
    .footer {
      text-align: center;
      margin-top: 30px;
      font-size: 11px;
      color: #666;
    }
    @media print {
      body {
        margin: 0;
        background-color: #fff;
      }
      .receipt-container {
        border: none;
        padding: 0;
        max-width: 100%;
      }
    }
  </style>
</head>
<body>
  <div class="receipt-container">
    <div class="header">
      <div class="shop-name">TRILOK JEWELLERS</div>
      <div class="shop-info">
        123 Main Road, MCET Junction, Pollachi<br>
        Phone: +91 98765 43210 | GSTIN: 33AAAAA1111A1Z1
      </div>
    </div>

    <div class="receipt-title">
      ${isReceipt ? 'Due Payment Receipt' : 'Old Gold Purchase Invoice'}
    </div>

    <table class="meta-table">
      <tr>
        <td width="50%">
          <span class="bold">Customer Details:</span><br>
          Name: ${v.acName}<br>
          Place of Supply: ${v.placeOfSupply.isEmpty ? '—' : v.placeOfSupply}
        </td>
        <td width="50%" class="text-right">
          <span class="bold">Voucher Details:</span><br>
          Voucher No: <span class="bold">${v.voucherNo}</span><br>
          Date: $dateFormatted<br>
          ${isReceipt ? '<span class="bold">Original Bill No: ${v.parentVoucherNo ?? "—"}</span><br>' : ''}
          Salesman: ${v.salesman.isEmpty ? '—' : v.salesman}
        </td>
      </tr>
    </table>

    <div class="divider"></div>

    ${!isReceipt ? '''
    <table class="items-table">
      <thead>
        <tr>
          <th>Sl</th>
          <th>Item Description</th>
          <th>Purity</th>
          <th align="right">Gross Wt</th>
          <th align="right">Net Wt</th>
          <th align="right">Fine Wt</th>
          <th align="right">Rate</th>
          <th align="right">Metal Amt</th>
          <th align="right">Labour</th>
          <th align="right">Total</th>
        </tr>
      </thead>
      <tbody>
        $itemsHtml
      </tbody>
    </table>
    ''' : '''
    <div style="padding: 15px 0; font-size: 13px; line-height: 1.6;">
      This receipt confirms a settlement payment of <span class="bold">₹${v.paymentAmt.toStringAsFixed(2)}</span> 
      towards the outstanding due of Original Voucher <span class="bold">${v.parentVoucherNo ?? ''}</span>.<br>
      Total original bill value was ₹${v.voucherAmt.toStringAsFixed(2)}.
    </div>
    '''}

    <div class="divider"></div>

    <table class="totals-table">
      ${!isReceipt ? '''
      <tr>
        <td width="60%">Total Metal Weight (Gross / Net):</td>
        <td width="40%" class="text-right bold">
          ${v.items.fold(0.0, (acc, i) => acc + i.grossWt).toStringAsFixed(3)}g / 
          ${v.items.fold(0.0, (acc, i) => acc + i.netWt).toStringAsFixed(3)}g
        </td>
      </tr>
      <tr>
        <td>Total Fine Weight:</td>
        <td class="text-right bold">${v.items.fold(0.0, (acc, i) => acc + i.fineWt).toStringAsFixed(3)}g</td>
      </tr>
      <tr>
        <td>Metal Value Total:</td>
        <td class="text-right">₹${v.metalAmtTotal.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td>Labour Value Total:</td>
        <td class="text-right">₹${v.labourAmtTotal.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td>Other Charges:</td>
        <td class="text-right">₹${v.otherCharges.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td>Discount:</td>
        <td class="text-right">-₹${v.discountAmt.toStringAsFixed(2)}</td>
      </tr>
      <tr>
        <td>Round Off:</td>
        <td class="text-right">₹${v.rndDiscount.toStringAsFixed(2)}</td>
      </tr>
      ''' : ''}
      
      <tr class="bold" style="font-size: 14px;">
        <td>${isReceipt ? 'Receipt Payment Amount:' : 'Voucher Total Amount:'}</td>
        <td class="text-right" style="color: #CA6F1E;">₹${(isReceipt ? v.paymentAmt : v.totalAmt).toStringAsFixed(2)}</td>
      </tr>
      
      <tr><td colspan="2"><div class="divider"></div></td></tr>
      
      <tr class="bold">
        <td>Payment Summary:</td>
        <td class="text-right">Mode Breakdown</td>
      </tr>
      ${v.cashAmt > 0 ? '<tr><td>Cash:</td><td class="text-right">₹${v.cashAmt.toStringAsFixed(2)}</td></tr>' : ''}
      ${v.bankAmt > 0 ? '<tr><td>Bank:</td><td class="text-right">₹${v.bankAmt.toStringAsFixed(2)}</td></tr>' : ''}
      ${v.cardAmt > 0 ? '<tr><td>Card:</td><td class="text-right">₹${v.cardAmt.toStringAsFixed(2)}</td></tr>' : ''}
      ${v.ogPurchase > 0 ? '<tr><td>OG Purchase Adjust:</td><td class="text-right">₹${v.ogPurchase.toStringAsFixed(2)}</td></tr>' : ''}
      
      <tr class="bold">
        <td>Total Paid in this transaction:</td>
        <td class="text-right">₹${v.paymentAmt.toStringAsFixed(2)}</td>
      </tr>
      
      <tr class="bold" style="color: #d32f2f;">
        <td>Remaining Outstanding Due:</td>
        <td class="text-right">₹${v.finalDue.toStringAsFixed(2)}</td>
      </tr>
    </table>

    <div class="double-divider"></div>

    <table style="width: 100%; margin-top: 40px;">
      <tr>
        <td width="33%" align="left" style="vertical-align: bottom;">
          <div style="border-top: 1px solid #aaa; width: 120px; margin-bottom: 5px;"></div>
          Customer Signature
        </td>
        <td width="34%" align="center" style="vertical-align: bottom;">
          Thank You! Please Visit Again.
        </td>
        <td width="33%" align="right" style="vertical-align: bottom;">
          <div style="border-top: 1px solid #aaa; width: 120px; margin-bottom: 5px; float: right;"></div><br style="clear:both;">
          Authorized Signatory
        </td>
      </tr>
    </table>

    <div class="footer">
      Generated digitally by Trilok MCET application on $dateFormatted
    </div>
  </div>

  <script>
    window.onload = function() {
      window.print();
    }
  </script>
</body>
</html>
    ''';

    try {
      if (kIsWeb) {
        final Uri uri = Uri.dataFromString(
          htmlContent,
          mimeType: 'text/html',
          encoding: Encoding.getByName('utf-8'),
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final Directory tempDir = await Directory.systemTemp.createTemp('trilok_print_');
        final safeVNo = v.voucherNo.replaceAll('/', '_').replaceAll(':', '_');
        final File tempFile = File('${tempDir.path}/invoice_$safeVNo.html');
        await tempFile.writeAsString(htmlContent);
        await launchUrl(Uri.file(tempFile.path), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching print layout: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

void _showPrintPreviewDialog(BuildContext context, OldGoldPurchase v) {
  final isReceipt = v.voucherType == 'Receipt';
  final dateFormatted = DateFormat('dd/MM/yyyy HH:mm').format(v.voucherDate);
  final grossWt = v.items.fold(0.0, (acc, i) => acc + i.grossWt);
  final netWt = v.items.fold(0.0, (acc, i) => acc + i.netWt);
  final fineWt = v.items.fold(0.0, (acc, i) => acc + i.fineWt);

  showDialog(
    context: context,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        child: Container(
          width: 600,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isReceipt ? '🧾 Payment Receipt Preview' : '📄 Invoice Bill Preview',
                    style: const TextStyle(
                      fontFamily: 'serif',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: _brownLight),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: _border, height: 16),
              
              // Scrollable Receipt Simulator
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFCF9),
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shop Details
                        const Center(
                          child: Column(
                            children: [
                              Text(
                                'TRILOK JEWELLERS',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _brown,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '123 Main Road, MCET Junction, Pollachi',
                                style: TextStyle(fontSize: 11, color: _brownLight),
                              ),
                              Text(
                                'Phone: +91 98765 43210 | GSTIN: 33AAAAA1111A1Z1',
                                style: TextStyle(fontSize: 11, color: _brownLight),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Dashed Divider
                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                          style: TextStyle(color: _border, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Center(
                          child: Text(
                            isReceipt ? 'DUE PAYMENT RECEIPT' : 'OLD GOLD PURCHASE INVOICE',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Meta Information Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Customer Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown)),
                                  Text('Name: ${v.acName}', style: const TextStyle(fontSize: 11, color: _brownLight)),
                                  Text('Place of Supply: ${v.placeOfSupply.isEmpty ? '—' : v.placeOfSupply}', style: const TextStyle(fontSize: 11, color: _brownLight)),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Voucher Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown)),
                                  Text('Voucher No: ${v.voucherNo}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _gold)),
                                  Text('Date: $dateFormatted', style: const TextStyle(fontSize: 11, color: _brownLight)),
                                  if (isReceipt)
                                    Text('Ref Bill No: ${v.parentVoucherNo ?? "—"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown)),
                                  Text('Salesman: ${v.salesman.isEmpty ? '—' : v.salesman}', style: const TextStyle(fontSize: 11, color: _brownLight)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                          style: TextStyle(color: _border, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Content (Items list or Receipt Text)
                        if (!isReceipt) ...[
                          const Text('Purchased Items:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _brown)),
                          const SizedBox(height: 6),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: v.items.length,
                            itemBuilder: (context, idx) {
                              final item = v.items[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Text('${idx + 1}. ', style: const TextStyle(fontSize: 11, color: _brownLight)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${item.itemName} (${item.group})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                                          Text('${item.purity.toStringAsFixed(1)}% | Gross: ${item.grossWt.toStringAsFixed(3)}g | Net: ${item.netWt.toStringAsFixed(3)}g', style: const TextStyle(fontSize: 10, color: _brownLight)),
                                        ],
                                      ),
                                    ),
                                    Text('₹${(item.metalAmount + item.labourAmount).toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50.withValues(alpha: 0.5),
                              border: Border.all(color: Colors.green.shade100),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'This receipt confirms a settlement payment of ₹${v.paymentAmt.toStringAsFixed(2)} towards the outstanding due of original voucher ${v.parentVoucherNo ?? ""}.',
                                  style: TextStyle(fontSize: 12, color: Colors.green.shade800, height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total original bill value was ₹${v.voucherAmt.toStringAsFixed(2)}.',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Text(
                          '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -',
                          style: TextStyle(color: _border, fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                        ),
                        const SizedBox(height: 8),

                        // Totals Summary
                        if (!isReceipt) ...[
                          _buildReceiptSummaryRow('Total Gross / Net Wt:', '${grossWt.toStringAsFixed(3)}g / ${netWt.toStringAsFixed(3)}g'),
                          _buildReceiptSummaryRow('Total Fine Wt:', '${fineWt.toStringAsFixed(3)}g'),
                          _buildReceiptSummaryRow('Metal Value Total:', '₹${v.metalAmtTotal.toStringAsFixed(2)}'),
                          _buildReceiptSummaryRow('Labour Value Total:', '₹${v.labourAmtTotal.toStringAsFixed(2)}'),
                          if (v.otherCharges > 0) _buildReceiptSummaryRow('Other Charges:', '₹${v.otherCharges.toStringAsFixed(2)}'),
                          if (v.discountAmt > 0) _buildReceiptSummaryRow('Discount:', '-₹${v.discountAmt.toStringAsFixed(2)}'),
                          if (v.rndDiscount != 0) _buildReceiptSummaryRow('Round Off:', '₹${v.rndDiscount.toStringAsFixed(2)}'),
                          const Divider(height: 12, color: _border),
                        ],

                        _buildReceiptSummaryRow(
                          isReceipt ? 'Receipt Payment Amount:' : 'Voucher Total Amount:',
                          '₹${(isReceipt ? v.paymentAmt : v.totalAmt).toStringAsFixed(2)}',
                          isBold: true,
                          valueColor: _gold,
                        ),
                        
                        const SizedBox(height: 8),
                        const Text('Payment Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: _brown)),
                        if (v.cashAmt > 0) _buildReceiptSummaryRow(' - Cash:', '₹${v.cashAmt.toStringAsFixed(2)}'),
                        if (v.bankAmt > 0) _buildReceiptSummaryRow(' - Bank:', '₹${v.bankAmt.toStringAsFixed(2)}'),
                        if (v.cardAmt > 0) _buildReceiptSummaryRow(' - Card:', '₹${v.cardAmt.toStringAsFixed(2)}'),
                        if (v.ogPurchase > 0) _buildReceiptSummaryRow(' - OG Purchase Adjust:', '₹${v.ogPurchase.toStringAsFixed(2)}'),
                        
                        const Divider(height: 12, color: _border),
                        _buildReceiptSummaryRow('Total Paid in this transaction:', '₹${v.paymentAmt.toStringAsFixed(2)}', isBold: true),
                        _buildReceiptSummaryRow('Remaining Outstanding Due:', '₹${v.finalDue.toStringAsFixed(2)}', isBold: true, valueColor: Colors.red.shade700),

                        const SizedBox(height: 24),
                        // Signature Simulation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 80, height: 1, color: _brownLight),
                                const SizedBox(height: 4),
                                const Text('Customer Sig', style: TextStyle(fontSize: 9, color: _brownLight)),
                              ],
                            ),
                            const Text('Thank you! Visit again.', style: TextStyle(fontSize: 10, color: _brownLight, fontStyle: FontStyle.italic)),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(width: 80, height: 1, color: _brownLight),
                                const SizedBox(height: 4),
                                const Text('Authorized Sig', style: TextStyle(fontSize: 9, color: _brownLight)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _brownLight,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _printVoucher(context, v);
                    },
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print Bill'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildReceiptSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: _brown,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: valueColor ?? _brown,
          ),
        ),
      ],
    ),
  );
}
