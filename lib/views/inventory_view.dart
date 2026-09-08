import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../state/admin_state.dart';
import '../models/product.dart';
import '../dialogs/item_dialog.dart';

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
  String _selectedPricingTab = 'Quantity-Based'; // Or 'Weight-Based'

  final List<String> _categories = [
    'All Categories',
    'Idols',
    'Pooja Thali Sets',
    'Lamps/Vilakku',
    'Incense/Agarbathi',
    'Camphor',
    'Oil/Ghee',
    'Bells',
    'Kalasam',
    'Religious Books',
    'Silver/Brass Items',
    'Decorative Items',
    'Festival Specials',
    'Others'
  ];

  final List<String> _statuses = [
    'All Statuses',
    'In Stock',
    'Reserved',
    'Sold Out',
    'Discontinued'
  ];

  @override
  void initState() {
    super.initState();
  }

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
        backgroundColor: const Color(0xFFF9F6F0),
        title: const Text('Delete Product', style: TextStyle(color: Color(0xFF3E2723))),
        content: Text('Are you sure you want to delete product $tagId?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF5D4037))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              // state.deleteProduct(tagId); // Implement in admin_state
              Navigator.of(context).pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String detailText,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DDD0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5DDD0)),
            ),
            child: Icon(icon, color: const Color(0xFFCA6F1E), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3E2723),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFF8D6E63),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  detailText,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ],
            ),
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

        final filteredList = allProducts.where((p) {
          final matchesSearch = _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery) ||
              p.tagId.toLowerCase().contains(_searchQuery);
          final matchesCategory = _selectedCategory == 'All Categories' || p.category == _selectedCategory;
          final matchesStatus = _selectedStatus == 'All Statuses' || p.status == _selectedStatus;
          final matchesPricing = p.pricingType == _selectedPricingTab;

          return matchesSearch && matchesCategory && matchesStatus && matchesPricing;
        }).toList();

        return Container(
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFCFAF5),
                  border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Inventory Dashboard',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3E2723),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3E2723),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showAddItemDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Item', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Dashboard Cards
                    LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
                        final cardWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                        final cards = [
                          _buildSummaryCard(
                            icon: Icons.inventory_2_outlined,
                            title: '${state.totalProductsCount}',
                            subtitle: 'TOTAL PRODUCTS',
                            detailText: '${state.availableProductsCount} Available • ${state.totalCategoriesUsed} Categories',
                            color: const Color(0xFFF9F6F0),
                          ),
                          _buildSummaryCard(
                            icon: Icons.production_quantity_limits,
                            title: '${state.totalQuantityBasedStock}',
                            subtitle: 'QUANTITY STOCK',
                            detailText: 'Total pieces in stock',
                            color: const Color(0xFFF9F6F0),
                          ),
                          _buildSummaryCard(
                            icon: Icons.scale_outlined,
                            title: 'Mixed',
                            subtitle: 'WEIGHT-BASED STOCK',
                            detailText: 'Gross Weight tracked',
                            color: const Color(0xFFF9F6F0),
                          ),
                          _buildSummaryCard(
                            icon: Icons.warning_amber_rounded,
                            title: '${state.lowStockCount}',
                            subtitle: 'LOW STOCK ALERTS',
                            detailText: 'Items with < 5 qty',
                            color: const Color(0xFFFFF3E0),
                          ),
                        ];

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Filter Bar
              Container(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by Tag ID or Name...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF8D6E63)),
                          filled: true,
                          fillColor: const Color(0xFFF9F6F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF9F6F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                        ),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCategory = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF9F6F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE5DDD0)),
                          ),
                        ),
                        items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedStatus = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Tabs for Pricing Type
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildTab('Quantity-Based'),
                    const SizedBox(width: 16),
                    _buildTab('Weight-Based'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Data Table
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5DDD0)),
                  ),
                  child: filteredList.isEmpty
                      ? const Center(child: Text('No items found.'))
                      : ListView.builder(
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            final p = filteredList[index];
                            return ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F6F0),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _selectedPricingTab == 'Quantity-Based'
                                      ? Icons.production_quantity_limits
                                      : Icons.scale_outlined,
                                  color: const Color(0xFF8D6E63),
                                ),
                              ),
                              title: Text(
                                '${p.tagId} - ${p.name}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                              ),
                              subtitle: Text(
                                _selectedPricingTab == 'Quantity-Based'
                                    ? '${p.category} • ${p.material} • Qty: ${p.quantity} ${p.unit} • MRP: ₹${p.mrp}'
                                    : '${p.category} • ${p.material} • Gross Wt: ${p.grossWeight}g • Net Wt: ${p.netWeight}g',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (p.isFestivalStock)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('Festival', style: TextStyle(fontSize: 10, color: Colors.deepOrange)),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    p.status,
                                    style: TextStyle(
                                      color: p.status == 'In Stock' ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Color(0xFF8D6E63)),
                                    onPressed: () => _showEditProductDialog(context, p),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                    onPressed: () => _confirmDeleteProduct(context, p.tagId),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTab(String title) {
    final isSelected = _selectedPricingTab == title;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPricingTab = title;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3E2723) : const Color(0xFFF9F6F0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF3E2723) : const Color(0xFFE5DDD0)),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF8D6E63),
          ),
        ),
      ),
    );
  }
}
