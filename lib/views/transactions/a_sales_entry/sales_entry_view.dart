import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../state/admin_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SalesEntryView extends StatefulWidget {
  final AdminState state;
  final Function(dynamic)? onBack;
  final Map<String, dynamic>? initialData;
  final bool isViewOnly;

  const SalesEntryView({
    super.key,
    required this.state,
    this.onBack,
    this.initialData,
    this.isViewOnly = false,
  });

  @override
  State<SalesEntryView> createState() => _SalesEntryViewState();
}

class _SalesEntryViewState extends State<SalesEntryView> {
  final TextEditingController _customerNameCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _cart = [];
  bool _isSaving = false;

  void _addToCart(Product p) {
    setState(() {
      final existing = _cart.indexWhere((e) => (e['product'] as Product).tagId == p.tagId);
      if (existing >= 0) {
        _cart[existing]['qty'] += 1;
      } else {
        double price = p.pricingType == 'Quantity-Based'
            ? p.sellingPrice
            : (p.grossWeight * p.ratePerGram + p.makingCharges);
        _cart.add({
          'product': p,
          'qty': 1,
          'price': price,
        });
      }
      _searchCtrl.clear();
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  double get _totalAmount {
    return _cart.fold(0.0, (sum, item) => sum + (item['price'] * item['qty']));
  }

  Future<void> _saveBill() async {
    if (_cart.isEmpty) return;
    setState(() => _isSaving = true);
    
    try {
      final docRef = FirebaseFirestore.instance.collection('bills').doc();
      final billData = {
        'billType': 'Sale',
        'customerName': _customerNameCtrl.text,
        'date': DateTime.now().toIso8601String(),
        'totalAmount': _totalAmount,
        'items': _cart.map((e) => {
          'tagId': (e['product'] as Product).tagId,
          'name': (e['product'] as Product).name,
          'qty': e['qty'],
          'price': e['price'],
        }).toList(),
      };
      
      await docRef.set(billData);

      // Deduct stock
      for (var item in _cart) {
        Product p = item['product'];
        int deductQty = item['qty'];
        if (p.pricingType == 'Quantity-Based') {
          p = p.copyWith(quantity: p.quantity - deductQty);
        } else {
          // Weight-based items are generally single pieces.
          p = p.copyWith(status: 'Sold Out');
        }
        await widget.state.updateProduct(p);
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill Saved & Stock Deducted!')));
      if (widget.onBack != null) widget.onBack!(null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFCFAF5),
        title: const Text('New Sales Entry', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF3E2723)),
          onPressed: () {
            if (widget.onBack != null) widget.onBack!(null);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Side: Product Search & Cart
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      labelText: 'Scan or Search Product (Tag ID)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF9F6F0),
                    ),
                    onSubmitted: (val) {
                      final p = widget.state.products.where((element) => element.tagId.toLowerCase() == val.toLowerCase()).firstOrNull;
                      if (p != null) {
                        if (p.status == 'Sold Out') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item is Sold Out!')));
                        } else {
                          _addToCart(p);
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product not found!')));
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Cart Items', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _cart.length,
                      itemBuilder: (context, index) {
                        final item = _cart[index];
                        final Product p = item['product'];
                        return Card(
                          color: const Color(0xFFF9F6F0),
                          child: ListTile(
                            title: Text('${p.tagId} - ${p.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Qty: ${item['qty']} x ₹${item['price']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _removeFromCart(index),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Side: Summary
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCFAF5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5DDD0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bill Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _customerNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Customer Name',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount:', style: TextStyle(fontSize: 18, color: Color(0xFF5D4037))),
                        Text('₹${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3E2723)),
                        onPressed: _isSaving ? null : _saveBill,
                        child: _isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Complete Sale', style: TextStyle(fontSize: 18, color: Colors.white)),
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
  }
}
