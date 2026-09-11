import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';

class ItemDialog extends StatefulWidget {
  final String adminEmail;
  final List<String> existingTagIds;
  final Product? initialProduct;
  final AdminState adminState;
  final dynamic liveRates;

  const ItemDialog({
    super.key,
    required this.adminEmail,
    required this.existingTagIds,
    required this.adminState,
    this.initialProduct,
    this.liveRates,
  });

  @override
  State<ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<ItemDialog> {
  // Controllers
  late TextEditingController _tagIdCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _sizeCtrl;
  late TextEditingController _vendorCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _mrpCtrl;
  late TextEditingController _sellingPriceCtrl;
  late TextEditingController _discountCtrl;

  String _discountType = '%'; // "%" or "₹"
  String _category = 'Idols';
  String _deity = 'General';
  String _material = 'Brass';
  String _status = 'In Stock';
  String _unit = 'Piece';
  bool _isFestivalStock = false;

  // Validation touched flags
  bool _tagIdTouched = false;
  bool _nameTouched = false;
  bool _categoryTouched = false;
  bool _sellingPriceTouched = false;
  bool _quantityTouched = false;

  static const _brown = Color(0xFF3E2723);
  static const _lightBrown = Color(0xFF8D6E63);
  static const _bg = Color(0xFFF9F6F0);
  static const _border = Color(0xFFE5DDD0);
  static const _errorColor = Color(0xFFB71C1C);

  final List<String> _categories = [
    'Idols', 'Pooja Thali Sets', 'Lamps/Vilakku', 'Incense/Agarbathi',
    'Camphor', 'Oil/Ghee', 'Bells', 'Kalasam', 'Religious Books',
    'Silver/Brass Items', 'Decorative Items', 'Festival Specials', 'Others'
  ];
  final List<String> _deities = [
    'Ganesh', 'Lakshmi', 'Krishna', 'Shiva', 'Ayyappa', 'Durga', 'General', 'Others'
  ];
  final List<String> _materials = [
    'Brass', 'Silver', 'Panchaloha', 'Wood', 'Clay', 'Marble', 'Plastic/Steel', 'N/A'
  ];
  final List<String> _statuses = ['In Stock', 'Sold Out'];
  final List<String> _units = ['Piece', 'Set', 'Pair', 'Box', 'Packet'];

  String _autoGenerateTagId() {
    int maxVal = 1000;
    for (final tag in widget.existingTagIds) {
      final match = RegExp(r'\d+').firstMatch(tag);
      if (match != null) {
        final val = int.tryParse(match.group(0)!) ?? 0;
        if (val > maxVal) maxVal = val;
      }
    }
    return 'FA-${maxVal + 1}';
  }

  List<String> get _availableCategories {
    final list = widget.adminState.categories.where((c) => c != 'All Categories').toList();
    if (list.isEmpty) return _categories;
    return list;
  }

  void _showAddCategoryDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Add New Category', style: TextStyle(fontFamily: 'serif', color: _brown)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Category Name (e.g. Sarees, Dresses)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown),
            onPressed: () {
              final cat = ctrl.text.trim();
              if (cat.isNotEmpty) {
                widget.adminState.addCategory(cat);
                setState(() => _category = cat);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    final defaultTagId = p?.tagId ?? _autoGenerateTagId();
    _tagIdCtrl = TextEditingController(text: defaultTagId);
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _sizeCtrl = TextEditingController(text: p?.size ?? '');
    _vendorCtrl = TextEditingController(text: p?.vendor ?? '');
    _notesCtrl = TextEditingController(text: p?.notes ?? '');
    _quantityCtrl = TextEditingController(text: p != null ? p.quantity.toString() : '1');
    _mrpCtrl = TextEditingController(text: p != null && p.mrp > 0 ? p.mrp.toString() : '');
    _sellingPriceCtrl = TextEditingController(text: p != null && p.sellingPrice > 0 ? p.sellingPrice.toString() : '');
    _discountCtrl = TextEditingController(text: p != null && p.discountValue > 0 ? p.discountValue.toString() : '');

    if (p != null) {
      _category = p.category.isNotEmpty ? p.category : 'Others';
      _deity = _deities.contains(p.deity) ? p.deity : 'General';
      _material = _materials.contains(p.material) ? p.material : 'Brass';
      _status = _statuses.contains(p.status) ? p.status : 'In Stock';
      final storedUnit = p.unit.isNotEmpty ? p.unit : 'Piece';
      final normUnit = _units.firstWhere(
        (u) => u.toLowerCase() == storedUnit.toLowerCase(),
        orElse: () => 'Piece',
      );
      _unit = normUnit;
      _isFestivalStock = p.isFestivalStock;
      _discountType = p.discountType.isNotEmpty ? p.discountType : '%';
    } else {
      if (_availableCategories.isNotEmpty) {
        _category = _availableCategories.first;
      }
    }

    // Note: price/discount listeners removed — the final price preview
    // uses AnimatedBuilder to listen directly to these controllers so only
    // that small widget rebuilds on keystroke, not the entire dialog.
  }

  @override
  void dispose() {
    _tagIdCtrl.dispose();
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _vendorCtrl.dispose();
    _notesCtrl.dispose();
    _quantityCtrl.dispose();
    _mrpCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  // ── Discount Calculation ──────────────────────────────────────────────────────

  double get _sellingPrice => double.tryParse(_sellingPriceCtrl.text) ?? double.tryParse(_mrpCtrl.text) ?? 0.0;
  double get _discountAmount => double.tryParse(_discountCtrl.text) ?? 0.0;

  double get _finalPrice {
    final sp = _sellingPrice;
    final d = _discountAmount;
    if (d <= 0) return sp;
    if (_discountType == '%') {
      return (sp - (sp * d / 100)).clamp(0.0, double.infinity);
    } else {
      return (sp - d).clamp(0.0, double.infinity);
    }
  }

  // ── Validation ────────────────────────────────────────────────────────────────

  String? _tagIdError() {
    if (!_tagIdTouched) return null;
    final v = _tagIdCtrl.text.trim();
    if (v.isEmpty) return 'Tag ID / SKU is required';
    final isEdit = widget.initialProduct != null;
    final isDuplicate = widget.existingTagIds
        .where((id) => isEdit ? id != widget.initialProduct!.tagId : true)
        .any((id) => id.toUpperCase() == v.toUpperCase());
    if (isDuplicate) return 'This Tag ID already exists';
    return null;
  }

  String? _nameError() {
    if (!_nameTouched) return null;
    if (_nameCtrl.text.trim().isEmpty) return 'Item Name is required';
    return null;
  }

  String? _categoryError() {
    if (!_categoryTouched) return null;
    if (_category.isEmpty) return 'Category is required';
    return null;
  }

  String? _quantityError() {
    if (!_quantityTouched) return null;
    final v = int.tryParse(_quantityCtrl.text);
    if (v == null || v < 0) return 'Quantity must be 0 or more';
    return null;
  }

  String? _discountError() {
    final d = double.tryParse(_discountCtrl.text);
    if (d == null && _discountCtrl.text.isNotEmpty) return 'Enter a valid number';
    if (d != null && d < 0) return 'Discount cannot be negative';
    if (d != null && _discountType == '%' && d > 100) return 'Discount % cannot exceed 100';
    if (d != null && _discountType == '₹' && d > _sellingPrice && _sellingPrice > 0) {
      return 'Discount cannot exceed Selling Price';
    }
    return null;
  }

  bool get _isFormValid {
    if (_tagIdCtrl.text.trim().isEmpty) return false;
    if (_tagIdError() != null) return false;
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_category.isEmpty) return false;
    final q = int.tryParse(_quantityCtrl.text);
    if (q == null || q < 0) return false;
    if (_discountError() != null) return false;
    return true;
  }

  Future<void> _save() async {
    setState(() {
      _tagIdTouched = true;
      _nameTouched = true;
      _categoryTouched = true;
      _sellingPriceTouched = true;
      _quantityTouched = true;
    });

    if (!_isFormValid) {
      BoutiqueToast.showError(context, 'Please fill in all required fields (Tag ID, Name, Category, Quantity).');
      return;
    }

    final product = Product(
      tagId: _tagIdCtrl.text.trim().toUpperCase(),
      name: _nameCtrl.text.trim(),
      category: _category,
      deity: _deity,
      material: _material,
      size: _sizeCtrl.text.trim(),
      status: _status,
      vendor: _vendorCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      pricingType: 'Quantity-Based',
      grossWeight: 0.0,
      netWeight: 0.0,
      ratePerGram: 0.0,
      makingCharges: 0.0,
      quantity: int.tryParse(_quantityCtrl.text) ?? 0,
      unit: _unit,
      mrp: double.tryParse(_mrpCtrl.text) ?? 0.0,
      sellingPrice: _sellingPrice,
      discountValue: _discountAmount,
      discountType: _discountType,
      finalPrice: _finalPrice,
      isFestivalStock: _isFestivalStock,
    );

    try {
      if (widget.initialProduct == null) {
        await widget.adminState.addProduct(product);
        if (mounted) BoutiqueToast.showSuccess(context, 'Product added successfully!');
      } else {
        await widget.adminState.updateProduct(product);
        if (mounted) BoutiqueToast.showSuccess(context, 'Product updated successfully!');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) BoutiqueToast.showError(context, 'Failed to save to Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialProduct != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: _bg,
      child: Container(
        width: 860,
        constraints: const BoxConstraints(maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
              decoration: const BoxDecoration(
                color: _brown,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(isEdit ? Icons.edit_rounded : Icons.add_box_rounded,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    isEdit ? 'Edit Item' : 'Add New Item',
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── Section 1: Identification ──────────────────────────
                    _sectionHeader('Identification', Icons.badge_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _field(
                          label: 'Tag ID / SKU *',
                          controller: _tagIdCtrl,
                          error: _tagIdError(),
                          hint: 'e.g. IDOL-001',
                          onChanged: (_) => setState(() => _tagIdTouched = true),
                          inputFormatters: [UpperCaseFormatter()],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _field(
                          label: 'Item Name *',
                          controller: _nameCtrl,
                          error: _nameError(),
                          hint: 'e.g. Ganesh Idol',
                          onChanged: (_) => setState(() => _nameTouched = true),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _dropdownWithError(
                                label: 'Category *',
                                value: _availableCategories.contains(_category) ? _category : (_availableCategories.isNotEmpty ? _availableCategories.first : 'Others'),
                                items: _availableCategories,
                                error: _categoryError(),
                                onChanged: (v) => setState(() {
                                  _category = v!;
                                  _categoryTouched = true;
                                }),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: _showAddCategoryDialog,
                              icon: const Icon(Icons.add_circle_outline, color: _brown),
                              tooltip: 'Add New Category',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _dropdown('Material', _material, _materials,
                          (v) => setState(() => _material = v!))),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _dropdown('Deity / Theme', _deity, _deities,
                          (v) => setState(() => _deity = v!))),
                      const SizedBox(width: 16),
                      Expanded(child: _dropdown('Status', _status, _statuses,
                          (v) => setState(() => _status = v!))),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: _field(
                        label: 'Size / Dimensions',
                        controller: _sizeCtrl,
                        hint: 'e.g. 6 inch',
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _field(
                        label: 'Vendor / Supplier',
                        controller: _vendorCtrl,
                        hint: 'Supplier name',
                      )),
                    ]),

                    const SizedBox(height: 24),

                    // ── Section 2: Stock & Unit ────────────────────────────
                    _sectionHeader('Stock & Unit', Icons.inventory_2_outlined),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: _field(
                          label: 'Quantity *',
                          controller: _quantityCtrl,
                          isNum: true,
                          isInt: true,
                          error: _quantityError(),
                          hint: '0',
                          onChanged: (_) => setState(() => _quantityTouched = true),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _dropdown(
                          'Unit *',
                          _units.contains(_unit) ? _unit : 'Piece',
                          _units,
                          (v) => setState(() => _unit = v!),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Section 3: Pricing & Discount ─────────────────────
                    _sectionHeader('Pricing & Discount', Icons.currency_rupee_rounded),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: _field(
                        label: 'Price (₹) *',
                        controller: _sellingPriceCtrl,
                        isNum: true,
                        hint: '0.00',
                        onChanged: (v) {
                          // Keep MRP in sync with price
                          _mrpCtrl.text = v;
                          setState(() => _sellingPriceTouched = true);
                        },
                      )),
                    ]),
                    const SizedBox(height: 16),

                    // Discount row
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          label: 'Default Discount',
                          controller: _discountCtrl,
                          isNum: true,
                          error: _discountError(),
                          hint: '0',
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Discount type toggle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Type', style: TextStyle(
                            fontSize: 12, color: _lightBrown, fontWeight: FontWeight.w600,
                          )),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                              color: Colors.white,
                            ),
                            child: Row(children: [
                              _discountTypeBtn('%'),
                              _discountTypeBtn('₹'),
                            ]),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Final Price — AnimatedBuilder so only this rebuilds on price/discount keystrokes
                      Expanded(
                        flex: 2,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_sellingPriceCtrl, _discountCtrl]),
                          builder: (context, _) {
                            final sp = double.tryParse(_sellingPriceCtrl.text) ?? 0.0;
                            final d = double.tryParse(_discountCtrl.text) ?? 0.0;
                            final fp = _discountType == '%'
                                ? (sp - sp * d / 100).clamp(0.0, double.infinity)
                                : (sp - d).clamp(0.0, double.infinity);
                            final mrp = double.tryParse(_mrpCtrl.text) ?? 0.0;
                            final pctOff = (mrp > 0 && fp < mrp) ? (mrp - fp) / mrp * 100 : null;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Final Price', style: TextStyle(
                                  fontSize: 12, color: _lightBrown, fontWeight: FontWeight.w600,
                                )),
                                const SizedBox(height: 6),
                                Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFA5D6A7)),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Row(children: [
                                    const Icon(Icons.currency_rupee, size: 16, color: Color(0xFF2E7D32)),
                                    Text(
                                      fp.toStringAsFixed(2),
                                      style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.bold,
                                        color: Color(0xFF2E7D32),
                                      ),
                                    ),
                                  ]),
                                ),
                                if (pctOff != null) ...[  
                                  const SizedBox(height: 6),
                                  Row(children: [
                                    const Icon(Icons.info_outline, size: 14, color: _lightBrown),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${pctOff.toStringAsFixed(1)}% off MRP',
                                      style: const TextStyle(fontSize: 12, color: _lightBrown),
                                    ),
                                  ]),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Section 4: Additional Details ──────────────────────
                    _sectionHeader('Additional Details', Icons.more_horiz_rounded),
                    const SizedBox(height: 12),
                    _field(
                      label: 'Notes',
                      controller: _notesCtrl,
                      maxLines: 2,
                      hint: 'Any extra details about this item...',
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => setState(() => _isFestivalStock = !_isFestivalStock),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isFestivalStock ? const Color(0xFFFFF3E0) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isFestivalStock ? Colors.orange : _border,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _isFestivalStock ? Icons.check_box : Icons.check_box_outline_blank,
                            color: _isFestivalStock ? Colors.orange : _lightBrown,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Festival Special Stock',
                            style: TextStyle(fontWeight: FontWeight.w600, color: _brown),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '(marks item for festival season)',
                            style: TextStyle(fontSize: 12, color: _lightBrown),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: _border)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  if (!_isFormValid && (_tagIdTouched || _nameTouched || _sellingPriceTouched || _quantityTouched))
                    const Row(children: [
                      Icon(Icons.error_outline, color: _errorColor, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Please fill all required fields correctly.',
                        style: TextStyle(color: _errorColor, fontSize: 12),
                      ),
                    ]),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel', style: TextStyle(color: _lightBrown)),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    opacity: _isFormValid ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(isEdit ? 'Update Product' : 'Save Product'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, IconData icon) {
    return Row(children: [
      Icon(icon, size: 16, color: _lightBrown),
      const SizedBox(width: 6),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.bold,
          letterSpacing: 1.2, color: _lightBrown,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Divider(color: _border, height: 1)),
    ]);
  }

  Widget _discountTypeBtn(String type) {
    final isSelected = _discountType == type;
    return GestureDetector(
      onTap: () => setState(() => _discountType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _brown : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          type,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : _lightBrown,
          ),
        ),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    String? error,
    String? hint,
    bool isNum = false,
    bool isInt = false,
    int maxLines = 1,
    void Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final hasError = error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _lightBrown,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          keyboardType: isNum
              ? (isInt
                  ? TextInputType.number
                  : const TextInputType.numberWithOptions(decimal: true))
              : TextInputType.text,
          inputFormatters: [
            if (isNum && isInt) FilteringTextInputFormatter.digitsOnly,
            if (isNum && !isInt)
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ...?inputFormatters,
          ],
          style: const TextStyle(color: _brown, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFBCAAA4)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? _errorColor : _border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: hasError ? _errorColor : _brown,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(
              error,
              style: const TextStyle(fontSize: 11, color: _errorColor),
            ),
          ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _lightBrown,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _brown, width: 1.5),
            ),
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
          style: const TextStyle(color: _brown, fontSize: 14),
        ),
      ],
    );
  }

  /// Dropdown with an inline error message below (for required dropdowns).
  Widget _dropdownWithError({
    required String label,
    required String value,
    required List<String> items,
    String? error,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _lightBrown,
          ),
        ),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          value: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: error != null ? _errorColor : _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: error != null ? _errorColor : _brown, width: 1.5),
            ),
          ),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: onChanged,
          style: const TextStyle(color: _brown, fontSize: 14),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 2),
            child: Text(error, style: const TextStyle(fontSize: 11, color: _errorColor)),
          ),
      ],
    );
  }
}

// ── Input Formatter ───────────────────────────────────────────────────────────

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
