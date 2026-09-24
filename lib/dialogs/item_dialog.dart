import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../state/admin_state.dart';
import '../utils/boutique_theme.dart';
import '../utils/excel_generator.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

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
  late TextEditingController _gstRateCtrl;
  late TextEditingController _reservedForCtrl;
  late TextEditingController _reservedQtyCtrl;
  late TextEditingController _ratePerGramCtrl;

  String _discountType = '%'; // "%" or "₹"
  String _pricingType = 'Quantity-Based'; // "Quantity-Based" or "Weight-Based"
  String _category = 'Idols';
  String _deity = 'General';
  String _material = 'Brass';
  String _status = 'In Stock';
  String _unit = 'Piece';
  String _weightUnit = 'Grams';
  bool _isReserved = false;

  // Validation touched flags
  bool _tagIdTouched = false;
  bool _nameTouched = false;
  bool _categoryTouched = false;
  bool _sellingPriceTouched = false;
  bool _quantityTouched = false;

  Uint8List? _imageBytes;
  String _imageUrl = '';
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

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
  final List<String> _statuses = ['In Stock', 'Sold Out', 'Damaged/Defective', 'Pending Return'];
  final List<String> _units = ['Piece', 'Set', 'Pair', 'Box', 'Packet'];

  String _autoGenerateTagId() {
    int maxVal = 0;
    for (final tag in widget.existingTagIds) {
      final match = RegExp(r'\d+').firstMatch(tag);
      if (match != null) {
        final val = int.tryParse(match.group(0)!) ?? 0;
        if (val > maxVal) maxVal = val;
      }
    }
    return 'RM-${(maxVal + 1).toString().padLeft(3, '0')}';
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  String _itemName = '';

  List<String> get _availableItemNames {
    final list = List<String>.from(widget.adminState.itemNames);
    if (_itemName.isNotEmpty && !list.contains(_itemName)) {
      list.insert(0, _itemName);
    }
    if (_nameCtrl.text.trim().isNotEmpty && !list.contains(_nameCtrl.text.trim())) {
      list.insert(0, _nameCtrl.text.trim());
    }
    return list.isNotEmpty ? list : ['Ganesh Idol', 'Lakshmi Idol', 'Diya / Vilakku'];
  }

  List<String> get _availableCategories {
    final list = widget.adminState.categories.where((c) => c != 'All Categories').toList();
    return list.isNotEmpty ? list : _categories;
  }

  List<String> get _availableMaterials {
    final list = widget.adminState.materials;
    return list.isNotEmpty ? list : _materials;
  }

  List<String> get _availableUnits {
    final list = widget.adminState.units;
    return list.isNotEmpty ? list : _units;
  }

  List<String> get _availableWeightUnits {
    final list = widget.adminState.weightUnits;
    return list.isNotEmpty ? list : ['g', 'kg', 'mg', 'carat'];
  }

  void _showEditItemPrompt(
    BuildContext parentContext,
    String type,
    String currentValue,
    Future<void> Function(String) onSave,
  ) {
    final editCtrl = TextEditingController(text: currentValue);
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.edit_outlined, color: _brown),
            const SizedBox(width: 8),
            Text('Edit $type', style: const TextStyle(fontFamily: 'serif', color: _brown, fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '$type Name',
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brown,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final val = editCtrl.text.trim();
              if (val.isNotEmpty && val != currentValue) {
                Navigator.pop(ctx);
                await onSave(val);
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showManageMasterListDialog(String type) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<String> currentItems;
            if (type == 'Category') {
              currentItems = widget.adminState.categories.where((c) => c != 'All Categories').toList();
            } else if (type == 'Material') {
              currentItems = widget.adminState.materials;
            } else if (type == 'Item Name') {
              currentItems = widget.adminState.itemNames;
            } else if (type == 'Weight Unit') {
              currentItems = widget.adminState.weightUnits;
            } else {
              currentItems = widget.adminState.units;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.settings_outlined, color: _brown),
                  const SizedBox(width: 8),
                  Text('Manage $type List', style: const TextStyle(fontFamily: 'serif', color: _brown, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 400,
                height: 420,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              hintText: 'Add new $type...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onSubmitted: (val) {
                              final text = val.trim();
                              if (text.isNotEmpty) {
                                if (type == 'Category') {
                                  widget.adminState.addCategory(text);
                                  setState(() => _category = text);
                                } else if (type == 'Material') {
                                  widget.adminState.addMaterial(text);
                                  setState(() => _material = text);
                                } else if (type == 'Item Name') {
                                  widget.adminState.addItemName(text);
                                  setState(() {
                                    _itemName = text;
                                    _nameCtrl.text = text;
                                  });
                                } else if (type == 'Unit') {
                                  widget.adminState.addUnit(text);
                                  setState(() => _unit = text);
                                }
                                ctrl.clear();
                                setDialogState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brown,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            final val = ctrl.text.trim();
                            if (val.isNotEmpty) {
                              if (type == 'Category') {
                                widget.adminState.addCategory(val);
                                setState(() => _category = val);
                              } else if (type == 'Material') {
                                widget.adminState.addMaterial(val);
                                setState(() => _material = val);
                              } else if (type == 'Item Name') {
                                widget.adminState.addItemName(val);
                                setState(() {
                                  _itemName = val;
                                  _nameCtrl.text = val;
                                });
                              } else if (type == 'Weight Unit') {
                                widget.adminState.addWeightUnit(val);
                                setState(() => _weightUnit = val);
                              } else if (type == 'Unit') {
                                widget.adminState.addUnit(val);
                                setState(() => _unit = val);
                              }
                              ctrl.clear();
                              setDialogState(() {});
                            }
                          },
                          child: const Text('Add', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Expanded(
                      child: currentItems.isEmpty
                          ? const Center(child: Text('No items in list'))
                          : ListView.separated(
                              itemCount: currentItems.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (ctx, i) {
                                final item = currentItems[i];
                                return ListTile(
                                  dense: true,
                                  title: Text(item, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: _lightBrown, size: 20),
                                        tooltip: 'Edit $type',
                                        onPressed: () => _showEditItemPrompt(context, type, item, (newVal) async {
                                          if (type == 'Category') {
                                            await widget.adminState.renameCategory(item, newVal);
                                            if (_category == item) setState(() => _category = newVal);
                                          } else if (type == 'Material') {
                                            await widget.adminState.renameMaterial(item, newVal);
                                            if (_material == item) setState(() => _material = newVal);
                                          } else if (type == 'Item Name') {
                                            await widget.adminState.renameItemName(item, newVal);
                                            if (_itemName == item) {
                                              setState(() {
                                                _itemName = newVal;
                                                _nameCtrl.text = newVal;
                                              });
                                            }
                                          } else if (type == 'Weight Unit') {
                                            await widget.adminState.updateWeightUnit(item, newVal);
                                            if (_weightUnit == item) setState(() => _weightUnit = newVal);
                                          } else if (type == 'Unit') {
                                            await widget.adminState.renameUnit(item, newVal);
                                            if (_unit == item) setState(() => _unit = newVal);
                                          }
                                          setDialogState(() {});
                                          setState(() {});
                                        }),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        tooltip: 'Delete $type',
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (c) => AlertDialog(
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                              title: Text('Delete $type', style: const TextStyle(fontFamily: 'serif', color: _brown, fontWeight: FontWeight.bold)),
                                              content: Text('Are you sure you want to remove "$item" from $type list?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(c, false),
                                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                                ),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                                  onPressed: () => Navigator.pop(c, true),
                                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            if (type == 'Category') {
                                              await widget.adminState.deleteCategory(item);
                                              if (_category == item) {
                                                setState(() => _category = _availableCategories.isNotEmpty ? _availableCategories.first : '');
                                              }
                                            } else if (type == 'Material') {
                                              await widget.adminState.deleteMaterial(item);
                                              if (_material == item) {
                                                setState(() => _material = _availableMaterials.isNotEmpty ? _availableMaterials.first : '');
                                              }
                                            } else if (type == 'Item Name') {
                                              await widget.adminState.deleteItemName(item);
                                              if (_itemName == item) {
                                                setState(() {
                                                  _itemName = _availableItemNames.isNotEmpty ? _availableItemNames.first : '';
                                                  _nameCtrl.text = _itemName;
                                                });
                                              }
                                            } else if (type == 'Weight Unit') {
                                              await widget.adminState.deleteWeightUnit(item);
                                              if (_weightUnit == item) {
                                                setState(() => _weightUnit = _availableWeightUnits.isNotEmpty ? _availableWeightUnits.first : '');
                                              }
                                            } else if (type == 'Unit') {
                                              await widget.adminState.deleteUnit(item);
                                              if (_unit == item) {
                                                setState(() => _unit = _availableUnits.isNotEmpty ? _availableUnits.first : '');
                                              }
                                            }
                                            setDialogState(() {});
                                            setState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: _brown, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onAdminStateChanged() {
    if (mounted) setState(() {});
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
    _ratePerGramCtrl = TextEditingController(text: p != null && p.ratePerGram > 0 ? p.ratePerGram.toString() : '');
    _discountCtrl = TextEditingController(text: p != null && p.discountValue > 0 ? p.discountValue.toString() : '');
    _gstRateCtrl = TextEditingController(text: p != null && p.gstRate > 0 ? (p.gstRate == p.gstRate.toInt() ? p.gstRate.toInt().toString() : p.gstRate.toString()) : '0');
    _reservedForCtrl = TextEditingController(text: p != null ? p.reservedFor : '');
    _reservedQtyCtrl = TextEditingController(text: p != null && p.reservedQuantity > 0 ? p.reservedQuantity.toString() : '');

    if (p != null && p.name.isNotEmpty) {
      _itemName = p.name;
    } else {
      if (_availableItemNames.isNotEmpty) {
        _itemName = _availableItemNames.first;
        _nameCtrl.text = _itemName;
      }
    }

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
      
      final storedWeightUnit = p.weightUnit.isNotEmpty ? p.weightUnit : 'g';
      final normWeightUnit = _availableWeightUnits.firstWhere(
        (u) => u.toLowerCase() == storedWeightUnit.toLowerCase(),
        orElse: () => 'g',
      );
      _weightUnit = normWeightUnit;
      
      _isReserved = p.isReserved;
      _discountType = p.discountType.isNotEmpty ? p.discountType : '%';
      _pricingType = p.pricingType.isNotEmpty ? p.pricingType : 'Quantity-Based';
    } else {
      if (_availableCategories.isNotEmpty) {
        _category = _availableCategories.first;
      }
    }

    widget.adminState.addListener(_onAdminStateChanged);
  }

  @override
  void dispose() {
    widget.adminState.removeListener(_onAdminStateChanged);
    _tagIdCtrl.dispose();
    _nameCtrl.dispose();
    _sizeCtrl.dispose();
    _vendorCtrl.dispose();
    _notesCtrl.dispose();
    _quantityCtrl.dispose();
    _mrpCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _ratePerGramCtrl.dispose();
    _discountCtrl.dispose();
    _gstRateCtrl.dispose();
    _reservedForCtrl.dispose();
    _reservedQtyCtrl.dispose();
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

  Future<void> _save({bool downloadInwardExcel = false}) async {
    setState(() {
      _tagIdTouched = true;
      _nameTouched = true;
      _categoryTouched = true;
      if (_pricingType == 'Quantity-Based') _sellingPriceTouched = true;
      _quantityTouched = true;
    });

    if (!_isFormValid) {
      BoutiqueToast.showError(context, 'Please fill in all required fields (Tag ID, Name, Category, Quantity).');
      return;
    }

    if (_imageBytes != null) {
      setState(() => _isUploading = true);
      try {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('product_images/$fileName');
        UploadTask uploadTask = storageRef.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        TaskSnapshot snapshot = await uploadTask.timeout(const Duration(seconds: 15), onTimeout: () {
          throw Exception('Upload timed out. Please check your Firebase Storage security rules or connection.');
        });
        _imageUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        if (mounted) BoutiqueToast.showError(context, 'Failed to upload image: $e');
        setState(() => _isUploading = false);
        return;
      }
      setState(() => _isUploading = false);
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
      pricingType: _pricingType,
      grossWeight: 0.0,
      netWeight: 0.0,
      ratePerGram: _pricingType == 'Weight-Based' ? (double.tryParse(_ratePerGramCtrl.text) ?? 0.0) : 0.0,
      makingCharges: 0.0,
      quantity: int.tryParse(_quantityCtrl.text) ?? 0,
      unit: _unit,
      mrp: _pricingType == 'Weight-Based' ? 0.0 : (double.tryParse(_mrpCtrl.text) ?? 0.0),
      sellingPrice: _pricingType == 'Weight-Based' ? 0.0 : _sellingPrice,
      discountValue: _discountAmount,
      discountType: _discountType,
      finalPrice: _pricingType == 'Weight-Based' ? 0.0 : _finalPrice,
      gstRate: double.tryParse(_gstRateCtrl.text) ?? 0.0,
      isReserved: _isReserved,
      reservedQuantity: _isReserved ? (int.tryParse(_reservedQtyCtrl.text) ?? (int.tryParse(_quantityCtrl.text) ?? 0)) : 0,
      reservedFor: _isReserved ? _reservedForCtrl.text.trim() : '',
      addedDate: widget.initialProduct?.addedDate ?? DateTime.now(),
      imageUrl: _imageUrl,
    );

    try {
      if (widget.initialProduct == null) {
        await widget.adminState.addProduct(product);
        if (mounted) {
          if (downloadInwardExcel) {
            await ExcelGenerator.downloadInwardBillExcel(products: [product]);
            if (mounted) BoutiqueToast.showSuccess(context, 'Product added & Inward Bill (.xlsx) downloaded!');
          } else {
            BoutiqueToast.showSuccess(context, 'Product added successfully!');
          }
        }
      } else {
        await widget.adminState.updateProduct(product);
        if (mounted) {
          if (downloadInwardExcel) {
            await ExcelGenerator.downloadInwardBillExcel(products: [product]);
            if (mounted) BoutiqueToast.showSuccess(context, 'Product updated & Inward Bill (.xlsx) downloaded!');
          } else {
            BoutiqueToast.showSuccess(context, 'Product updated successfully!');
          }
        }
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

                    // ── Product Image ──────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                            image: _imageBytes != null
                                ? DecorationImage(image: MemoryImage(_imageBytes!), fit: BoxFit.cover)
                                : (_imageUrl.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(_imageUrl), fit: BoxFit.cover)
                                    : null),
                          ),
                          child: _imageBytes == null && _imageUrl.isEmpty
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, color: Colors.grey, size: 30),
                                    SizedBox(height: 8),
                                    Text('Add Photo', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _dropdownWithError(
                                label: 'Item Name *',
                                value: _availableItemNames.contains(_itemName)
                                    ? _itemName
                                    : (_availableItemNames.isNotEmpty ? _availableItemNames.first : ''),
                                items: _availableItemNames,
                                error: _nameError(),
                                onChanged: (v) => setState(() {
                                  if (v != null) {
                                    _itemName = v;
                                    _nameCtrl.text = v;
                                    _nameTouched = true;
                                  }
                                }),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _showManageMasterListDialog('Item Name'),
                              icon: const Icon(Icons.settings_outlined, color: _brown),
                              tooltip: 'Manage Item Names',
                            ),
                          ],
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
                              onPressed: () => _showManageMasterListDialog('Category'),
                              icon: const Icon(Icons.settings_outlined, color: _brown),
                              tooltip: 'Manage Categories',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _dropdown(
                                'Material',
                                _availableMaterials.contains(_material) ? _material : (_availableMaterials.isNotEmpty ? _availableMaterials.first : 'Brass'),
                                _availableMaterials,
                                (v) => setState(() => _material = v!),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _showManageMasterListDialog('Material'),
                              icon: const Icon(Icons.settings_outlined, color: _brown),
                              tooltip: 'Manage Materials',
                            ),
                          ],
                        ),
                      ),
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
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: _dropdown(
                                'Unit *',
                                _availableUnits.contains(_unit) ? _unit : (_availableUnits.isNotEmpty ? _availableUnits.first : 'Piece'),
                                _availableUnits,
                                (v) => setState(() => _unit = v!),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _showManageMasterListDialog('Unit'),
                              icon: const Icon(Icons.settings_outlined, color: _brown),
                              tooltip: 'Manage Units',
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // ── Section 3: Pricing & Discount ─────────────────────
                    _sectionHeader('Pricing & Discount', Icons.currency_rupee_rounded),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _border),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _pricingType = 'Quantity-Based'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _pricingType == 'Quantity-Based' ? _brown : Colors.transparent,
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('Fixed Price', style: TextStyle(color: _pricingType == 'Quantity-Based' ? Colors.white : _lightBrown, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _pricingType = 'Weight-Based'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                      decoration: BoxDecoration(
                                        color: _pricingType == 'Weight-Based' ? _brown : Colors.transparent,
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text('By Weight', style: TextStyle(color: _pricingType == 'Weight-Based' ? Colors.white : _lightBrown, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _field(
                                  label: 'GST Rate (%)',
                                  controller: _gstRateCtrl,
                                  isNum: true,
                                  hint: '0',
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.arrow_drop_down, color: _brown),
                                tooltip: 'Common GST Rates',
                                onSelected: (v) {
                                  if (v == 'Custom') {
                                    _gstRateCtrl.clear();
                                  } else {
                                    _gstRateCtrl.text = v;
                                  }
                                },
                                itemBuilder: (context) {
                                  final items = ['0', '5', '12', '18', '28']
                                      .map((r) => PopupMenuItem(value: r, child: Text('$r%')))
                                      .toList();
                                  items.add(const PopupMenuItem(value: 'Custom', child: Text('Custom')));
                                  return items;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _pricingType == 'Weight-Based'
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _field(
                                    label: 'Rate per $_weightUnit (₹) *',
                                    controller: _ratePerGramCtrl,
                                    isNum: true,
                                    hint: 'e.g. 85.50',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _dropdown(
                                              'Unit',
                                              _availableWeightUnits.contains(_weightUnit) ? _weightUnit : (_availableWeightUnits.isNotEmpty ? _availableWeightUnits.first : 'g'),
                                              _availableWeightUnits,
                                              (v) => setState(() => _weightUnit = v!),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            onPressed: () => _showManageMasterListDialog('Weight Unit'),
                                            icon: const Icon(Icons.settings_outlined, color: _brown),
                                            tooltip: 'Manage Units',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : _field(
                              label: 'Price (₹) *',
                              controller: _sellingPriceCtrl,
                              isNum: true,
                              hint: '0.00',
                              onChanged: (v) {
                                _mrpCtrl.text = v;
                                setState(() => _sellingPriceTouched = true);
                              },
                            ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _pricingType == 'Weight-Based'
                          ? const SizedBox.shrink()
                          : const SizedBox.shrink(), // placeholder for balance in layout
                      ),
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
                      if (_pricingType == 'Quantity-Based')
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
                      onTap: () => setState(() => _isReserved = !_isReserved),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isReserved ? const Color(0xFFE8F5E9) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isReserved ? Colors.green : _border,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _isReserved ? Icons.check_box : Icons.check_box_outline_blank,
                            color: _isReserved ? Colors.green : _lightBrown,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Reserved for Customer',
                            style: TextStyle(fontWeight: FontWeight.w600, color: _brown),
                          ),
                        ]),
                      ),
                    ),
                    if (_isReserved) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              label: 'Reserved Qty',
                              controller: _reservedQtyCtrl,
                              isNum: true,
                              hint: 'e.g. 2',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              label: 'Customer Details (Name/Number)',
                              controller: _reservedForCtrl,
                              hint: 'e.g. John Doe - 9876543210',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline, size: 14, color: Color(0xFFB45309)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Reserved Qty will be deducted from sellable stock. Available = Total − Issue − Reserved.',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ),
                        ]),
                      ),
                    ],
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
                    child: OutlinedButton.icon(
                      onPressed: (_isFormValid && !_isUploading) ? () => _save(downloadInwardExcel: true) : null,
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Save & Inward Bill (.xlsx)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E7E34),
                        side: const BorderSide(color: Color(0xFF1E7E34)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedOpacity(
                    opacity: _isFormValid ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton.icon(
                      onPressed: _isUploading ? null : () => _save(downloadInwardExcel: false),
                      icon: _isUploading 
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _brown, strokeWidth: 2.5))
                          : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded, size: 18),
                      label: Text(
                        _isUploading ? 'Uploading...' : (isEdit ? 'Update Product' : 'Save Product'),
                        style: TextStyle(color: _isUploading ? _brown : Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isUploading ? Colors.grey.shade300 : _brown,
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
          key: ValueKey(value),
          initialValue: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
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
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
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
          key: ValueKey(value),
          initialValue: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
          isExpanded: true,
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
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, overflow: TextOverflow.ellipsis))).toList(),
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
