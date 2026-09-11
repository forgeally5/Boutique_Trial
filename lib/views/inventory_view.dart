import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/admin_state.dart';
import '../models/product.dart';
import '../dialogs/item_dialog.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../utils/boutique_theme.dart';

class InventoryView extends StatefulWidget {
  final AdminState state;
  const InventoryView({super.key, required this.state});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  AdminState get state => widget.state;

  String _searchQuery = '';
  String _selectedCategory = 'All Categories';
  String _selectedStatus = 'All Statuses';
  bool _isGridView = false;
  Product? _selectedDrawerProduct;

  // ── Memoized filter cache ──
  List<Product> _cachedFilteredList = [];
  List<Product> _lastSourceProducts = [];
  String _lastSearch = '';
  String _lastCategory = '';
  String _lastStatus = '';

  List<Product> _getFilteredList(List<Product> allProducts) {
    // Only recompute when inputs change
    if (identical(allProducts, _lastSourceProducts) &&
        _searchQuery == _lastSearch &&
        _selectedCategory == _lastCategory &&
        _selectedStatus == _lastStatus) {
      return _cachedFilteredList;
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
          _selectedCategory == 'All Categories' || p.category == _selectedCategory;
      final matchesStatus =
          _selectedStatus == 'All Statuses' || p.status == _selectedStatus;
      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
    return _cachedFilteredList;
  }

  final List<String> _statuses = [
    'All Statuses',
    'In Stock',
    'Reserved',
    'Sold Out',
    'Discontinued'
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
              // Actually delete from Firestore + local state
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
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final List<Product> allProducts = state.products;
        final filteredList = _getFilteredList(allProducts);

        return Stack(
          children: [
            Column(
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
                          const Column(
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
                          Row(
                            children: [
                              // View Toggle (Table / Grid)
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
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
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
                              SizedBox(width: w, child: _buildMiniStat('Total Stock', '${state.totalStockQuantity} pcs', Icons.inventory_2_outlined, BoutiqueColors.accentSoft)),
                              SizedBox(width: w, child: _buildMiniStat('In Stock', '${state.availableProductsCount}', Icons.check_circle_outline, const Color(0xFFE8F5E9))),
                              SizedBox(width: w, child: _buildMiniStat('Low Stock', '${state.lowStockCount}', Icons.warning_amber_rounded, BoutiqueColors.lowStockBg)),
                              SizedBox(width: w, child: _buildMiniStat('Categories', '${state.totalCategoriesUsed}', Icons.category_outlined, BoutiqueColors.goldSoft)),
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
                        child: TextField(
                          style: const TextStyle(fontSize: 13),
                          decoration: BoutiqueInputDecoration.field(
                            hintText: 'Search product name or tag ID...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: BoutiqueColors.textSecondary),
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Category Filter
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: state.categories.contains(_selectedCategory) ? _selectedCategory : 'All Categories',
                          style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                          decoration: BoutiqueInputDecoration.field(hintText: 'Category'),
                          items: state.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Status Filter
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedStatus,
                          style: const TextStyle(fontSize: 13, color: BoutiqueColors.textPrimary),
                          decoration: BoutiqueInputDecoration.field(hintText: 'Status'),
                          items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedStatus = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Main Content View (Table or Grid)
                Expanded(
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
                                  return _buildGridCard(p);
                                },
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: BoutiqueColors.borderLight),
                                itemBuilder: (context, index) {
                                  final p = filteredList[index];
                                  return _buildTableRow(p);
                                },
                              )),
                  ),
                ),
              ],
            ),

            // Side Drawer Overlay (When product is selected)
            if (_selectedDrawerProduct != null)
              Positioned.fill(
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
          ],
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

  Widget _buildMiniStat(String label, String value, IconData icon, Color bg) {
    return Container(
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
    );
  }

  Widget _buildTableRow(Product p) {
    final isLowStock = p.quantity < 5;
    final matStr = p.material.isNotEmpty ? ' • ${p.material}' : '';
    return Material(
      color: Colors.transparent,
      child: ListTile(
      onTap: () => setState(() => _selectedDrawerProduct = p),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: BoutiqueColors.accentSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.inventory_2_outlined, color: BoutiqueColors.accent, size: 22),
        ),
      ),
      title: Row(
        children: [
          Text(p.tagId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: BoutiqueColors.accent)),
          const SizedBox(width: 10),
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: BoutiqueColors.textPrimary)),
          if (isLowStock) ...[
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
        '${p.category}$matStr • Qty: ${p.quantity} ${p.unit} • Price: ₹${p.mrp}',
        style: const TextStyle(fontSize: 12, color: BoutiqueColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('₹${p.mrp}', style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: BoutiqueColors.textSecondary, size: 20),
            onPressed: () => _showEditProductDialog(context, p),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: BoutiqueColors.destructive, size: 20),
            onPressed: () => _confirmDeleteProduct(context, p.tagId),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildGridCard(Product p) {
    final isLowStock = p.quantity < 5;
    return InkWell(
      onTap: () => setState(() => _selectedDrawerProduct = p),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoutiqueDecoration.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: BoutiqueColors.accentSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text(p.tagId, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: BoutiqueColors.accent)),
                ),
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: BoutiqueColors.lowStockBg, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Low Stock', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                  ),
              ],
            ),
            const Center(
              child: Icon(Icons.inventory_2_outlined, size: 48, color: BoutiqueColors.accent),
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
                    Text('₹${p.mrp}', style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.bold, color: BoutiqueColors.textPrimary)),
                    Text('Qty: ${p.quantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BoutiqueColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideDrawer(Product p) {
    final matStr = p.material.isNotEmpty ? p.material : 'N/A';
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
                icon: const Icon(Icons.close_rounded, color: BoutiqueColors.textSecondary),
                onPressed: () => setState(() => _selectedDrawerProduct = null),
              ),
            ],
          ),
          const Divider(height: 24, color: BoutiqueColors.border),
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: BoutiqueColors.accentSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.inventory_2_outlined, size: 48, color: BoutiqueColors.accent),
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
          _buildDetailRow('Stock Quantity', '${p.quantity} ${p.unit}'),
          _buildDetailRow('MRP Price', '₹${p.mrp}'),
          _buildDetailRow('Status', p.status),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: BoutiqueColors.destructive),
                  ),
                  onPressed: () => _confirmDeleteProduct(context, p.tagId),
                  icon: const Icon(Icons.delete_outline, color: BoutiqueColors.destructive, size: 18),
                  label: const Text('Delete', style: TextStyle(color: BoutiqueColors.destructive)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BoutiqueColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    setState(() => _selectedDrawerProduct = null);
                    _showEditProductDialog(context, p);
                  },
                  icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                  label: const Text('Edit Item', style: TextStyle(color: Colors.white)),
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
