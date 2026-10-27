import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../state/admin_state.dart';
import '../models/product.dart';
import '../dialogs/item_dialog.dart';
import '../auth/models/app_user_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../utils/boutique_theme.dart';
import '../utils/excel_generator.dart';
import '../utils/qr_pdf_generator.dart';
import '../dialogs/bulk_upload_dialog.dart';
import '../widgets/searchable_dropdown.dart';

enum ProductAction {
  row,
  qr,
  download,
  edit,
  delete,
}

class InventoryView extends StatefulWidget {
  final AdminState state;
  final TextEditingController? globalSearchCtrl;
  const InventoryView({super.key, required this.state, this.globalSearchCtrl});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  AdminState get state => widget.state;
  PermissionsModel get perms => context.read<AuthViewModel>().appUser?.permissions ?? PermissionsModel.adminPreset();

  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Statuses';
  bool _isGridView = false;
  Product? _selectedDrawerProduct;
  final TextEditingController _searchCtrl = TextEditingController();
  DateTimeRange? _selectedDateRange;
  int _selectedProductIndex = 0;
  final ScrollController _listScrollCtrl = ScrollController();
  late final FocusNode _searchFocusNode;
  late final FocusNode _dateFilterFocusNode;
  final Map<int, FocusNode> _itemFocusNodes = {};
  final Map<int, FocusNode> _qrFocusNodes = {};
  final Map<int, FocusNode> _downloadFocusNodes = {};
  final Map<int, FocusNode> _editFocusNodes = {};
  final Map<int, FocusNode> _deleteFocusNodes = {};

  FocusNode _getItemFocusNode(int index) {
    return _itemFocusNodes.putIfAbsent(
      index,
      () => FocusNode(debugLabel: 'product_row_$index', skipTraversal: true),
    );
  }

  FocusNode _getActionFocusNode(int index, ProductAction action) {
    switch (action) {
      case ProductAction.row:
        return _getItemFocusNode(index);
      case ProductAction.qr:
        return _qrFocusNodes.putIfAbsent(
          index,
          () => FocusNode(debugLabel: 'qr_$index', skipTraversal: true),
        );
      case ProductAction.download:
        return _downloadFocusNodes.putIfAbsent(
          index,
          () => FocusNode(debugLabel: 'download_$index', skipTraversal: true),
        );
      case ProductAction.edit:
        return _editFocusNodes.putIfAbsent(
          index,
          () => FocusNode(debugLabel: 'edit_$index', skipTraversal: true),
        );
      case ProductAction.delete:
        return _deleteFocusNodes.putIfAbsent(
          index,
          () => FocusNode(debugLabel: 'delete_$index', skipTraversal: true),
        );
    }
  }

  List<ProductAction> _getAvailableActions(PermissionsModel perms) {
    final actions = <ProductAction>[ProductAction.row];
    if (perms.tagBarcodePrint || perms.editTags) {
      actions.add(ProductAction.qr);
    }
    actions.add(ProductAction.download);
    if (perms.editTags) {
      actions.add(ProductAction.edit);
    }
    if (perms.deleteTags) {
      actions.add(ProductAction.delete);
    }
    return actions;
  }

  void _clearItemFocusNodes() {
    for (final n in _itemFocusNodes.values) {
      n.dispose();
    }
    _itemFocusNodes.clear();
    for (final n in _qrFocusNodes.values) {
      n.dispose();
    }
    _qrFocusNodes.clear();
    for (final n in _downloadFocusNodes.values) {
      n.dispose();
    }
    _downloadFocusNodes.clear();
    for (final n in _editFocusNodes.values) {
      n.dispose();
    }
    _editFocusNodes.clear();
    for (final n in _deleteFocusNodes.values) {
      n.dispose();
    }
    _deleteFocusNodes.clear();
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final node = _getItemFocusNode(index);
      if (node.context != null) {
        Scrollable.ensureVisible(
          node.context!,
          alignment: 0.35,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
        );
      } else if (_listScrollCtrl.hasClients) {
        final approxItemHeight = _isGridView ? 280.0 : 70.0;
        final targetOffset = (index * approxItemHeight).clamp(0.0, _listScrollCtrl.position.maxScrollExtent);
        _listScrollCtrl.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _selectProductAt(int targetIndex, List<Product> list, {bool openDrawer = false}) {
    if (list.isEmpty) return;
    final clampedIndex = targetIndex.clamp(0, list.length - 1);
    setState(() {
      _selectedProductIndex = clampedIndex;
      if (openDrawer) {
        _selectedDrawerProduct = list[clampedIndex];
      } else if (_selectedDrawerProduct != null) {
        _selectedDrawerProduct = list[clampedIndex];
      }
    });

    final nextNode = _getItemFocusNode(clampedIndex);
    nextNode.requestFocus();
    _scrollToIndex(clampedIndex);
  }

  void _focusProductAction(int index, ProductAction action, List<Product> list) {
    if (list.isEmpty) return;
    final clampedIndex = index.clamp(0, list.length - 1);
    if (_selectedProductIndex != clampedIndex) {
      setState(() => _selectedProductIndex = clampedIndex);
    }
    final node = _getActionFocusNode(clampedIndex, action);
    node.requestFocus();

    // Ensure row is comfortably visible
    final rowNode = _getItemFocusNode(clampedIndex);
    if (rowNode.context != null) {
      Scrollable.ensureVisible(
        rowNode.context!,
        alignment: 0.35,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _dateFilterFocusNode = FocusNode(debugLabel: 'inventory_date_filter');
    _searchFocusNode = FocusNode(
      debugLabel: 'inventory_search',
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            final filteredList = _getFilteredList(state.products);
            if (filteredList.isNotEmpty) {
              _selectProductAt(0, filteredList);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );
    // Listen to global search from top bar
    widget.globalSearchCtrl?.addListener(_onGlobalSearch);
  }

  void _onGlobalSearch() {
    final q = widget.globalSearchCtrl?.text.trim().toLowerCase() ?? '';
    if (q != _searchQuery) {
      _searchCtrl.text = widget.globalSearchCtrl?.text ?? '';
      setState(() {
        _searchQuery = q;
        _selectedProductIndex = 0;
      });
      _clearItemFocusNodes();
    }
  }

  @override
  void dispose() {
    widget.globalSearchCtrl?.removeListener(_onGlobalSearch);
    _searchFocusNode.dispose();
    _dateFilterFocusNode.dispose();
    _searchCtrl.dispose();
    _listScrollCtrl.dispose();
    _clearItemFocusNodes();
    super.dispose();
  }

  Future<void> _openDateRangePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      barrierDismissible: true,
      builder: (dialogContext, child) {
        return Theme(
          data: Theme.of(dialogContext).copyWith(
            colorScheme: const ColorScheme.light(
              primary: BoutiqueColors.accent,
            ),
          ),
          child: FocusScope(
            autofocus: true,
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  Navigator.of(dialogContext).pop(null);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: child!,
            ),
          ),
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  // ── Memoized filter cache ──
  List<Product> _cachedFilteredList = [];
  List<Product> _lastSourceProducts = [];
  String _lastSearch = '';
  String _lastCategory = '';
  String _lastStatus = '';
  bool _filterLowStockOnly = false;

  List<Product> _getFilteredList(List<Product> allProducts) {
    if (identical(allProducts, _lastSourceProducts) &&
        _searchQuery == _lastSearch &&
        _selectedCategory == _lastCategory &&
        _selectedStatus == _lastStatus &&
        _selectedDateRange == null) {
      return _cachedFilteredList.where((p) => !_filterLowStockOnly || p.quantity < 5).toList();
    }
    _lastSourceProducts = allProducts;
    _lastSearch = _searchQuery;
    _lastCategory = _selectedCategory;
    _lastStatus = _selectedStatus;
    _cachedFilteredList = allProducts.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery) ||
          p.tagId.toLowerCase().contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          p.category.trim().toLowerCase() == _selectedCategory.trim().toLowerCase();
      final matchesStatus = _selectedStatus == 'All Statuses' ||
          (_selectedStatus == 'Out of Stock'
              ? (p.quantity <= 0 || p.status == 'Out of Stock' || p.status == 'Sold Out')
              : (_selectedStatus == 'Low Stock'
                  ? (p.quantity > 0 && p.quantity < 5)
                  : (_selectedStatus == 'In Stock'
                      ? (p.quantity > 0 && p.status != 'Sold Out' && p.status != 'Out of Stock')
                      : (_selectedStatus == 'Reserved'
                          ? (p.isReserved && p.reservedQuantity > 0)
                          : p.status == _selectedStatus))));
      
      final matchesDate = _selectedDateRange == null ||
          (p.addedDate != null &&
              p.addedDate!.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) &&
              p.addedDate!.isBefore(_selectedDateRange!.end.add(const Duration(days: 1))));

      return matchesSearch && matchesCategory && matchesStatus && matchesDate;
    }).toList();
    return _cachedFilteredList.where((p) => !_filterLowStockOnly || (p.quantity > 0 && p.quantity < 5)).toList();
  }

  final List<String> _statuses = [
    'All Statuses',
    'In Stock',
    'Low Stock',
    'Out of Stock',
    'Reserved',
  ];

  void _showAddItemDialog(BuildContext context) async {
    final adminEmail = context.read<AuthViewModel>().adminUser?.email ?? '';
    await showDialog(
      context: context,
      builder: (context) => ItemDialog(
        adminEmail: adminEmail,
        existingTagIds: state.allTagIds,
        adminState: state,
      ),
    );
  }

  void _showEditProductDialog(BuildContext context, Product product) async {
    final adminEmail = context.read<AuthViewModel>().adminUser?.email ?? '';
    await showDialog(
      context: context,
      builder: (context) => ItemDialog(
        adminEmail: adminEmail,
        existingTagIds: state.allTagIds,
        adminState: state,
        initialProduct: product,
      ),
    );
  }

  void _handleRefresh() {
    _searchCtrl.clear();
    widget.globalSearchCtrl?.clear();
    setState(() {
      _searchQuery = '';
      _selectedCategory = 'All Categories';
      _selectedStatus = 'All Statuses';
      _selectedDateRange = null;
      _filterLowStockOnly = false;
      _selectedProductIndex = 0;
      _selectedDrawerProduct = null;
    });
    _clearItemFocusNodes();
    state.fetchProducts();
  }

  void _confirmDeleteProduct(BuildContext context, String tagId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: BoutiqueColors.bgCard,
        title: const Text('Delete Product', style: TextStyle(fontFamily: 'serif', color: BoutiqueColors.textPrimary)),
        content: Text('Are you sure you want to delete product $tagId?'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: BoutiqueColors.border),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: BoutiqueColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: BoutiqueColors.destructive),
            onPressed: () {
              Navigator.of(context).pop();
              // Clear drawer selection if this product was open
              if (_selectedDrawerProduct?.tagId == tagId) {
                setState(() => _selectedDrawerProduct = null);
              }
              // Actually delete from API + local state
              state.deleteProduct(tagId);
              BoutiqueToast.showSuccess(context, 'Product deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthViewModel>().appUser;
    final perms = authUser?.permissions ?? PermissionsModel.adminPreset();

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final List<Product> allProducts = state.products;
        final filteredList = _getFilteredList(allProducts);

        return FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Stack(
            children: [
              ExcludeFocus(
                excluding: _selectedDrawerProduct != null,
                child: Column(
                  children: [
                // Top Header Section
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  decoration: const BoxDecoration(
                    color: BoutiqueColors.bgCard,
                    border: Border(bottom: BorderSide(color: BoutiqueColors.border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Inventory Catalog',
                                  style: TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: BoutiqueColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Manage products, stock quantities, and categories.',
                                  style: TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Refresh Button
                              Tooltip(
                                message: 'Refresh inventory from server (F5)',
                                child: state.isLoadingProducts
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: BoutiqueColors.accentSoft,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: BoutiqueColors.accentLightBorder),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: BoutiqueColors.accent,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Refreshing...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: BoutiqueColors.accent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : OutlinedButton.icon(
                                        icon: const Icon(Icons.refresh_rounded, size: 16, color: BoutiqueColors.accent),
                                        label: const Text(
                                          'Refresh',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: BoutiqueColors.accent,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: BoutiqueColors.bgCard,
                                          side: const BorderSide(color: BoutiqueColors.accentLightBorder),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        ),
                                        onPressed: _handleRefresh,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: BoutiqueColors.bgSubtle,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: BoutiqueColors.border),
                                ),
                                child: Row(
                                  children: [
                                    _buildViewToggleButton(
                                      icon: Icons.view_list_rounded,
                                      label: 'Table',
                                      isSelected: !_isGridView,
                                      onTap: () => setState(() => _isGridView = false),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildViewToggleButton(
                                      icon: Icons.grid_view_rounded,
                                      label: 'Grid',
                                      isSelected: _isGridView,
                                      onTap: () => setState(() => _isGridView = true),
                                    ),
                                  ],
                                ),
                              ),
                              if (perms.addTags) ...[
                                const SizedBox(width: 16),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(1),
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF1E7E34),
                                      side: const BorderSide(color: Color(0xFF1E7E34)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () async {
                                      final products = _getFilteredList(state.products);
                                      if (products.isEmpty) {
                                        BoutiqueToast.showError(context, 'No products to export.');
                                        return;
                                      }
                                      try {
                                        await ExcelGenerator.downloadInwardBillExcel(products: products);
                                        if (mounted) {
                                          // ignore: use_build_context_synchronously
                                          BoutiqueToast.showSuccess(context, 'Inward Bill Excel (${products.length} products) downloaded!');
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          // ignore: use_build_context_synchronously
                                          BoutiqueToast.showError(context, 'Failed to generate Inward Bill: $e');
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.table_view_rounded, size: 18),
                                    label: const Text('Inward Bill (Excel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(2),
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: BoutiqueColors.accent,
                                      side: const BorderSide(color: BoutiqueColors.accent),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () {
                                      final adminState = context.read<AdminState>();
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => ChangeNotifierProvider.value(
                                          value: adminState,
                                          child: const BulkUploadDialog(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                                    label: const Text('Bulk Import', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                FocusTraversalOrder(
                                  order: const NumericFocusOrder(3),
                                  child: ElevatedButton.icon(
                                    autofocus: true,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: BoutiqueColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    onPressed: () => _showAddItemDialog(context),
                                    icon: const Icon(Icons.add_rounded, size: 18),
                                    label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Metrics Bar — 4 stat cards
                      LayoutBuilder(
                        builder: (context, constraints) {
                          int count = constraints.maxWidth > 1100 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);
                          final w = (constraints.maxWidth - (count - 1) * 12) / count;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: w,
                                child: _buildMiniStat(
                                  'Total Stock',
                                  '${state.totalStockQuantity} pcs',
                                  Icons.inventory_2_outlined,
                                  BoutiqueColors.accentSoft,
                                  onTap: () => setState(() {
                                    _selectedStatus = 'All Statuses';
                                    _selectedCategory = 'All Categories';
                                    _filterLowStockOnly = false;
                                    _searchCtrl.clear();
                                    _searchQuery = '';
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _buildMiniStat(
                                  'In Stock',
                                  '${state.availableProductsCount}',
                                  Icons.check_circle_outline,
                                  _selectedStatus == 'In Stock' && !_filterLowStockOnly
                                      ? const Color(0xFFC8E6C9)
                                      : const Color(0xFFE8F5E9),
                                  onTap: () => setState(() {
                                    _selectedStatus = _selectedStatus == 'In Stock' ? 'All Statuses' : 'In Stock';
                                    _filterLowStockOnly = false;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _buildMiniStat(
                                  'Low Stock',
                                  '${state.lowStockCount}',
                                  Icons.warning_amber_rounded,
                                  _filterLowStockOnly ? const Color(0xFFFDE68A) : BoutiqueColors.lowStockBg,
                                  onTap: () => setState(() {
                                    _filterLowStockOnly = !_filterLowStockOnly;
                                  }),
                                ),
                              ),
                              SizedBox(
                                width: w,
                                child: _buildMiniStat(
                                  'Categories',
                                  '${state.totalCategoriesUsed}',
                                  Icons.category_outlined,
                                  BoutiqueColors.goldSoft,
                                  onTap: () => setState(() {
                                    _selectedCategory = 'All Categories';
                                    _filterLowStockOnly = false;
                                  }),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Filters Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  color: BoutiqueColors.bgMain,
                  child: Row(
                    children: [
                      // Search Input
                      Expanded(
                        flex: 3,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(4),
                          child: TextField(
                            focusNode: _searchFocusNode,
                            controller: _searchCtrl,
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 13),
                            decoration: BoutiqueInputDecoration.field(
                              hintText: 'Search product name or tag ID...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: BoutiqueColors.textSecondary),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 16, color: BoutiqueColors.textSecondary),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        widget.globalSearchCtrl?.clear();
                                        setState(() {
                                          _searchQuery = '';
                                          _selectedProductIndex = 0;
                                        });
                                        _clearItemFocusNodes();
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (val) {
                              final filteredList = _getFilteredList(state.products);
                              if (filteredList.isNotEmpty) {
                                _selectProductAt(0, filteredList);
                              }
                            },
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.toLowerCase();
                                _selectedProductIndex = 0;
                              });
                              _clearItemFocusNodes();
                              // Sync back to global search
                              if (widget.globalSearchCtrl != null &&
                                  widget.globalSearchCtrl!.text != val) {
                                widget.globalSearchCtrl!.text = val;
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Builder(builder: (context) {
                        final filterCats = <String>{
                          'All Categories',
                          ...state.categories.where((c) => c != 'All Categories'),
                          ...state.products.map((p) => p.category.trim()).where((c) => c.isNotEmpty)
                        }.toList();
                        return Expanded(
                          flex: 2,
                          child: FocusTraversalOrder(
                            order: const NumericFocusOrder(5),
                            child: SearchableDropdownField(
                              label: 'Category',
                              value: filterCats.any((c) => c.toLowerCase() == _selectedCategory.toLowerCase()) ? _selectedCategory : 'All Categories',
                              items: filterCats,
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                      // Status Filter
                      Expanded(
                        flex: 2,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(6),
                          child: SearchableDropdownField(
                            label: 'Status',
                            value: _selectedStatus,
                            items: _statuses,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Date Filter
                      Expanded(
                        flex: 2,
                        child: FocusTraversalOrder(
                          order: const NumericFocusOrder(7),
                          child: Focus(
                            focusNode: _dateFilterFocusNode,
                            onKeyEvent: (node, event) {
                              if (event is KeyDownEvent) {
                                if (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.space ||
                                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                  _openDateRangePicker(context);
                                  return KeyEventResult.handled;
                                }
                              }
                              return KeyEventResult.ignored;
                            },
                            child: ListenableBuilder(
                              listenable: _dateFilterFocusNode,
                              builder: (context, _) {
                                final isFocused = _dateFilterFocusNode.hasFocus;
                                return Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  child: InkWell(
                                    canRequestFocus: false,
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () => _openDateRangePicker(context),
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                          color: isFocused ? BoutiqueColors.accent : BoutiqueColors.border,
                                          width: isFocused ? 1.5 : 1.0,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 18,
                                            color: isFocused ? BoutiqueColors.accent : BoutiqueColors.textSecondary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedDateRange == null
                                                  ? 'Filter by Date Added'
                                                  : '${_selectedDateRange!.start.day}/${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}/${_selectedDateRange!.end.month}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isFocused ? BoutiqueColors.accent : BoutiqueColors.textPrimary,
                                                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (_selectedDateRange != null)
                                            IconButton(
                                              icon: const Icon(Icons.close, size: 16),
                                              onPressed: () => setState(() => _selectedDateRange = null),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                        ],
                                      ),
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

                const SizedBox(height: 12),

                // Main Content View (Table or Grid)
                Expanded(
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(8),
                    child: FocusTraversalGroup(
                      policy: WidgetOrderTraversalPolicy(),
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              _selectProductAt(_selectedProductIndex + 1, filteredList);
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              if (_selectedProductIndex > 0) {
                                _selectProductAt(_selectedProductIndex - 1, filteredList);
                              } else {
                                _searchFocusNode.requestFocus();
                                _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
                              }
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              final availableActions = _getAvailableActions(perms);
                              if (availableActions.length > 1 && filteredList.isNotEmpty) {
                                _focusProductAction(_selectedProductIndex, availableActions[1], filteredList);
                                return KeyEventResult.handled;
                              }
                            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                              _searchFocusNode.requestFocus();
                              _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
                              return KeyEventResult.handled;
                            } else if (event.logicalKey == LogicalKeyboardKey.enter && _selectedDrawerProduct == null) {
                              if (filteredList.isNotEmpty && _selectedProductIndex >= 0 && _selectedProductIndex < filteredList.length) {
                                setState(() => _selectedDrawerProduct = filteredList[_selectedProductIndex]);
                                return KeyEventResult.handled;
                              }
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                          decoration: BoutiqueDecoration.card(),
                          child: filteredList.isEmpty
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.inventory_outlined, size: 48, color: BoutiqueColors.textMuted),
                                      SizedBox(height: 12),
                                      Text('No matching items found in catalog.', style: TextStyle(color: BoutiqueColors.textSecondary, fontSize: 14)),
                                    ],
                                  ),
                                )
                              : (_isGridView
                                  ? GridView.builder(
                                      controller: _listScrollCtrl,
                                      padding: const EdgeInsets.all(20),
                                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 260,
                                        childAspectRatio: 0.85,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                      itemCount: filteredList.length,
                                      itemBuilder: (context, index) {
                                        final p = filteredList[index];
                                        return _buildGridCard(p, index, filteredList);
                                      },
                                    )
                                  : ListView.separated(
                                      controller: _listScrollCtrl,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      itemCount: filteredList.length,
                                      separatorBuilder: (_, _) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                      itemBuilder: (context, index) {
                                        final p = filteredList[index];
                                        return _buildTableRow(p, index, filteredList);
                                      },
                                    )),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

            // Side Drawer Overlay (When product is selected)
            if (_selectedDrawerProduct != null)
              Positioned.fill(
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () {
                      setState(() => _selectedDrawerProduct = null);
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowDown): () {
                      _selectProductAt(_selectedProductIndex + 1, filteredList);
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      _selectProductAt(_selectedProductIndex - 1, filteredList);
                    },
                  },
                  child: FocusScope(
                    autofocus: true,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDrawerProduct = null),
                      child: Container(
                        color: Colors.black26,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {}, // Prevent click propagation
                            child: _buildSideDrawer(_selectedDrawerProduct!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        );
      },
    );
  }

  Widget _buildViewToggleButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? BoutiqueColors.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected ? BoutiqueDecoration.softShadow : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? BoutiqueColors.accent : BoutiqueColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? BoutiqueColors.accent : BoutiqueColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon, Color bg, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: BoutiqueColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: BoutiqueColors.textPrimary),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: BoutiqueColors.textPrimary)),
                Text(label, style: const TextStyle(fontSize: 10, color: BoutiqueColors.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowActionButton({
    required ProductAction action,
    required int index,
    required List<Product> list,
    required Product product,
    required PermissionsModel perms,
    required IconData icon,
    required Color color,
    required Color focusBorderColor,
    required Color focusBgColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final focusNode = _getActionFocusNode(index, action);
    final availableActions = _getAvailableActions(perms);

    return Focus(
      focusNode: focusNode,
      skipTraversal: false,
      onFocusChange: (hasF) {
        if (hasF) {
          if (_selectedProductIndex != index) {
            setState(() => _selectedProductIndex = index);
          }
          _scrollToIndex(index);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            onPressed();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _selectProductAt(index + 1, list);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (index > 0) {
              _selectProductAt(index - 1, list);
            } else {
              _searchFocusNode.requestFocus();
              _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final pos = availableActions.indexOf(action);
            if (pos >= 0 && pos < availableActions.length - 1) {
              _focusProductAction(index, availableActions[pos + 1], list);
              return KeyEventResult.handled;
            }
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final pos = availableActions.indexOf(action);
            if (pos > 1) {
              _focusProductAction(index, availableActions[pos - 1], list);
            } else {
              _getItemFocusNode(index).requestFocus();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final isFocused = focusNode.hasFocus;
          return Tooltip(
            message: '$tooltip (Enter)',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                canRequestFocus: false,
                onTap: onPressed,
                borderRadius: BorderRadius.circular(8),
                hoverColor: focusBgColor.withValues(alpha: 0.6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isFocused ? focusBorderColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isFocused ? focusBorderColor : Colors.transparent,
                      width: 2.0,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: focusBorderColor.withValues(alpha: 0.45),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isFocused ? Colors.white : color,
                    size: 20,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableRow(Product p, int index, List<Product> list) {
    final isOutOfStock = p.quantity <= 0;
    final isLowStock = p.quantity > 0 && p.quantity < 5;
    final matStr = p.material.isNotEmpty ? ' • ${p.material}' : '';
    final isSelected = _selectedProductIndex == index;
    final rowNode = _getItemFocusNode(index);
    final availableActions = _getAvailableActions(perms);

    return Focus(
      focusNode: rowNode,
      skipTraversal: false,
      onFocusChange: (hasF) {
        if (hasF) {
          if (_selectedProductIndex != index) {
            setState(() => _selectedProductIndex = index);
          }
          _scrollToIndex(index);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _selectProductAt(index + 1, list);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (index > 0) {
              _selectProductAt(index - 1, list);
            } else {
              _searchFocusNode.requestFocus();
              _searchCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _searchCtrl.text.length));
            }
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (availableActions.length > 1) {
              _focusProductAction(index, availableActions[1], list);
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _selectedDrawerProduct = p);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: rowNode,
        builder: (context, _) {
          final isRowFocused = rowNode.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isRowFocused
                      ? BoutiqueColors.accentSoft
                      : BoutiqueColors.accentSoft.withValues(alpha: 0.6))
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? BoutiqueColors.accent : Colors.transparent,
                  width: 4,
                ),
              ),
              boxShadow: (isSelected && isRowFocused)
                  ? [
                      BoxShadow(
                        color: BoutiqueColors.accent.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                selected: isSelected,
                selectedTileColor: Colors.transparent,
                onTap: () {
                  _selectProductAt(index, list, openDrawer: true);
                },
                hoverColor: BoutiqueColors.accentSoft.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 42,
                    height: 42,
                    color: isSelected ? BoutiqueColors.bgCard : BoutiqueColors.accentSoft,
                    child: p.imageUrl.isNotEmpty 
                        ? Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.inventory_2_outlined, color: BoutiqueColors.accent, size: 22),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined, color: BoutiqueColors.accent, size: 22),
                          ),
                  ),
                ),
                title: Row(
                  children: [
                    Text(p.tagId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.accent)),
                    const SizedBox(width: 10),
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BoutiqueColors.textPrimary)),
                    if (isOutOfStock) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Out of Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                      ),
                    ] else if (isLowStock) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: BoutiqueColors.lowStockBg, borderRadius: BorderRadius.circular(4)),
                        child: const Text('Low Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${p.category}$matStr • Qty: ${p.sellableQuantity} ${p.unit}${p.reservedQuantity > 0 ? ' (Res: ${p.reservedQuantity})' : ''}${p.notes.trim().isNotEmpty ? ' • Notes: ${p.notes.trim()}' : ''}',
                  style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildPriceDisplay(p),
                    const SizedBox(width: 12),
                    if (perms.tagBarcodePrint || perms.editTags)
                      _buildRowActionButton(
                        action: ProductAction.qr,
                        index: index,
                        list: list,
                        product: p,
                        perms: perms,
                        icon: Icons.qr_code_2_rounded,
                        color: BoutiqueColors.accent,
                        focusBorderColor: BoutiqueColors.accent,
                        focusBgColor: BoutiqueColors.accentSoft,
                        tooltip: 'Print QR Label',
                        onPressed: () => QrPdfGenerator.printProductQr(p),
                      ),
                    _buildRowActionButton(
                      action: ProductAction.download,
                      index: index,
                      list: list,
                      product: p,
                      perms: perms,
                      icon: Icons.download_rounded,
                      color: const Color(0xFF1E7E34),
                      focusBorderColor: const Color(0xFF1E7E34),
                      focusBgColor: const Color(0xFFE8F5E9),
                      tooltip: 'Download Inward Bill (.xlsx)',
                      onPressed: () async {
                        await ExcelGenerator.downloadInwardBillExcel(products: [p]);
                        if (!context.mounted) return;
                        BoutiqueToast.showSuccess(context, 'Inward Bill (.xlsx) downloaded for ${p.tagId}!');
                      },
                    ),
                    if (perms.editTags)
                      _buildRowActionButton(
                        action: ProductAction.edit,
                        index: index,
                        list: list,
                        product: p,
                        perms: perms,
                        icon: Icons.edit_outlined,
                        color: BoutiqueColors.textSecondary,
                        focusBorderColor: BoutiqueColors.accent,
                        focusBgColor: const Color(0xFFF1F5F9),
                        tooltip: 'Edit Product',
                        onPressed: () => _showEditProductDialog(context, p),
                      ),
                    if (perms.deleteTags)
                      _buildRowActionButton(
                        action: ProductAction.delete,
                        index: index,
                        list: list,
                        product: p,
                        perms: perms,
                        icon: Icons.delete_outline_rounded,
                        color: BoutiqueColors.destructive,
                        focusBorderColor: BoutiqueColors.destructive,
                        focusBgColor: const Color(0xFFFFEBEE),
                        tooltip: 'Delete Product',
                        onPressed: () => _confirmDeleteProduct(context, p.tagId),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridCard(Product p, int index, List<Product> list) {
    final isOutOfStock = p.quantity <= 0;
    final isLowStock = p.quantity > 0 && p.quantity < 5;
    final isSelected = _selectedProductIndex == index;

    return Focus(
      focusNode: _getItemFocusNode(index),
      skipTraversal: false,
      onFocusChange: (hasF) {
        if (hasF) {
          if (_selectedProductIndex != index) {
            setState(() => _selectedProductIndex = index);
          }
          _scrollToIndex(index);
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _selectProductAt(index + 1, list);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _selectProductAt(index - 1, list);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            setState(() => _selectedDrawerProduct = p);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        canRequestFocus: false,
        onTap: () => _selectProductAt(index, list, openDrawer: true),
        hoverColor: BoutiqueColors.accentSoft.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? BoutiqueColors.accentSoft.withValues(alpha: 0.5) : BoutiqueColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? BoutiqueColors.accent : BoutiqueColors.borderLight,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? BoutiqueDecoration.softShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? BoutiqueColors.accent : BoutiqueColors.accentSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p.tagId,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : BoutiqueColors.accent,
                      ),
                    ),
                  ),
                  if (isOutOfStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Out of Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                    )
                  else if (isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: BoutiqueColors.lowStockBg, borderRadius: BorderRadius.circular(4)),
                      child: const Text('Low Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                    ),
                ],
              ),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: BoutiqueColors.accentSoft,
                    child: p.imageUrl.isNotEmpty
                        ? Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(Icons.inventory_2_outlined, size: 36, color: BoutiqueColors.accent),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined, size: 36, color: BoutiqueColors.accent),
                          ),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BoutiqueColors.textPrimary)),
                  Text(p.category, style: const TextStyle(fontSize: 11, color: BoutiqueColors.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPriceDisplay(p),
                      Expanded(
                        child: Text(
                          'Qty: ${p.sellableQuantity}${p.reservedQuantity > 0 ? '\n(Res: ${p.reservedQuantity})' : ''}${p.notes.trim().isNotEmpty ? '\n${p.notes.trim()}' : ''}',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BoutiqueColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceDisplay(Product p) {
    if (p.pricingType == 'Weight-Based') {
      return Text(
        '₹${p.ratePerGram.toStringAsFixed(p.ratePerGram.truncateToDouble() == p.ratePerGram ? 0 : 2)}/${p.weightUnit}',
        style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
      );
    }
    
    final basePrice = p.sellingPrice > 0 ? p.sellingPrice : p.mrp;
    final finalPrice = p.finalPrice > 0 ? p.finalPrice : basePrice;
    final hasDiscount = (p.discountValue > 0 || (p.mrp > finalPrice && p.mrp > 0)) && finalPrice < basePrice;

    if (!hasDiscount) {
      return Text(
        '₹${basePrice.toStringAsFixed(basePrice.truncateToDouble() == basePrice ? 0 : 2)}',
        style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₹${basePrice.toStringAsFixed(basePrice.truncateToDouble() == basePrice ? 0 : 2)}',
          style: const TextStyle(
            fontFamily: 'serif',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: BoutiqueColors.textSecondary,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF81C784), width: 0.8),
          ),
          child: Text(
            '₹${finalPrice.toStringAsFixed(finalPrice.truncateToDouble() == finalPrice ? 0 : 2)}',
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSideDrawer(Product p) {
    final matStr = p.material.isNotEmpty ? p.material : 'N/A';
    final effectiveSellingPrice = p.finalPrice > 0
        ? p.finalPrice
        : (p.sellingPrice > 0 ? p.sellingPrice : p.mrp);

    return Container(
      width: 380,
      height: double.infinity,
      color: BoutiqueColors.bgCard,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Item Details', style: TextStyle(fontFamily: 'serif', fontSize: 22, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
              IconButton(
                autofocus: true,
                tooltip: 'Close (Esc)',
                style: IconButton.styleFrom(
                  focusColor: BoutiqueColors.accentSoft,
                  hoverColor: BoutiqueColors.accentSoft.withValues(alpha: 0.5),
                ),
                icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                onPressed: () => setState(() => _selectedDrawerProduct = null),
              ),
            ],
          ),
          const Divider(height: 24, color: BoutiqueColors.border),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 100,
                height: 100,
                color: BoutiqueColors.accentSoft,
                child: p.imageUrl.isNotEmpty
                    ? Image.network(
                        p.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.inventory_2_outlined, size: 48, color: BoutiqueColors.accent),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.inventory_2_outlined, size: 48, color: BoutiqueColors.accent),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(p.name, style: const TextStyle(fontFamily: 'serif', fontSize: 20, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
          ),
          Center(
            child: Text(p.tagId, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Category', p.category),
          _buildDetailRow('Material', matStr),
          if (p.pricingType == 'Weight-Based' && p.grossWeight > 0)
            _buildDetailRow('Total Stock', '${p.grossWeight} ${p.weightUnit}'),
          _buildDetailRow(p.pricingType == 'Weight-Based' ? 'Pieces' : 'Stock Quantity', '${p.quantity} ${p.unit}'),
          if (p.mrp > 0 && p.mrp != effectiveSellingPrice) ...[
            _buildDetailRow('MRP Price', '₹${p.mrp}'),
            _buildDetailRow('Selling Price', '₹$effectiveSellingPrice'),
          ] else ...[
            _buildDetailRow('Selling Price', '₹$effectiveSellingPrice'),
          ],
          _buildDetailRow('Status', p.status),
          const Spacer(),
          Row(
            children: [
              if (perms.deleteTags)
                Expanded(
                  child: OutlinedButton.icon(
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(color: BoutiqueColors.destructive, width: 2.5);
                        }
                        return const BorderSide(color: BoutiqueColors.destructive, width: 1);
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return BoutiqueColors.destructive.withValues(alpha: 0.12);
                        }
                        return Colors.transparent;
                      }),
                    ),
                    onPressed: () => _confirmDeleteProduct(context, p.tagId),
                    icon: const Icon(Icons.delete_outline, color: BoutiqueColors.destructive, size: 18),
                    label: const Text('Delete', style: TextStyle(color: BoutiqueColors.destructive, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (perms.deleteTags && perms.editTags) const SizedBox(width: 12),
              if (perms.editTags)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(BoutiqueColors.accent),
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 14)),
                      side: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return const BorderSide(color: Colors.black87, width: 2.5);
                        }
                        return BorderSide.none;
                      }),
                      elevation: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.focused)) {
                          return 6;
                        }
                        return 0;
                      }),
                    ),
                    onPressed: () {
                      setState(() => _selectedDrawerProduct = null);
                      _showEditProductDialog(context, p);
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text('Edit Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: BoutiqueColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
        ],
      ),
    );
  }
}
