import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../products/repositories/product_repository.dart';
import '../state/admin_state.dart';
import '../dialogs/add_customer_dialog.dart';
import 'item_prefix_view.dart';

class AddMasterDialog extends StatefulWidget {
  final AdminState? adminState;
  const AddMasterDialog({super.key, this.adminState});

  @override
  State<AddMasterDialog> createState() => _AddMasterDialogState();
}

class _AddMasterDialogState extends State<AddMasterDialog> {
  final ProductRepository _productRepo = ProductRepository();
  int _activeTab = 0;

  // Search queries
  String _searchQuery = '';

  // Controllers for adding options
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _styleController = TextEditingController();
  final TextEditingController _salesmanController = TextEditingController();
  final TextEditingController _counterController = TextEditingController();
  final TextEditingController _repairTypeController = TextEditingController();

  // Metal Group Controllers
  final TextEditingController _metalIdController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  // GSTHSN Controllers
  final TextEditingController _hsnCodeController = TextEditingController();
  final TextEditingController _hsnDateController = TextEditingController();
  final TextEditingController _hsnIgstController = TextEditingController();
  final TextEditingController _hsnCgstController = TextEditingController();
  final TextEditingController _hsnSgstController = TextEditingController();
  final TextEditingController _hsnDescController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = false;

  String? _linkedRateId;
  String? _selectedCardBank;
  String? _selectedUpiBank;

  // Loaded lists
  List<String> _itemNames = [];
  List<String> _bankNames = [];
  List<Map<String, String>> _metalGroups = [];
  List<String> _extraStyles = [];
  List<String> _salesmen = [];
  List<String> _counters = [];
  List<String> _repairTypesList = [];
  List<Map<String, dynamic>> _customerList = [];
  List<Map<String, dynamic>> _supplierList = [];
  List<Map<String, dynamic>> _gstHsnList = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _itemController.dispose();
    _bankController.dispose();
    _styleController.dispose();
    _salesmanController.dispose();
    _counterController.dispose();
    _repairTypeController.dispose();
    _metalIdController.dispose();
    _groupNameController.dispose();
    _hsnCodeController.dispose();
    _hsnDateController.dispose();
    _hsnIgstController.dispose();
    _hsnCgstController.dispose();
    _hsnSgstController.dispose();
    _hsnDescController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final items = await _productRepo.getUniqueItemNames();
      final groups = await _productRepo.getUniqueMetalGroups();
      final styles = await _productRepo.getUniqueExtraStyles();
      final salesmenList = await _productRepo.getUniqueSalesmen();
      final countersList = await _productRepo.getUniqueCounters();

      // Fetch bank names
      final bankSnap = await FirebaseFirestore.instance
          .collection('book_names')
          .orderBy('name')
          .get();
      final banks = bankSnap.docs
          .map((d) => d.data()['name']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();

      String? cardB;
      String? upiB;
      try {
        final mappingDoc = await FirebaseFirestore.instance
            .collection('settings')
            .doc('bank_mappings')
            .get();
        if (mappingDoc.exists) {
          final mData = mappingDoc.data();
          if (mData != null) {
            cardB = mData['cardBank']?.toString();
            upiB = mData['upiBank']?.toString();
          }
        }
      } catch (e) {
        debugPrint('Error loading bank mappings settings: $e');
      }

      // Fetch repair types
      final repairSnap = await FirebaseFirestore.instance
          .collection('repair_types')
          .orderBy('name')
          .get();
      List<String> repairs = [];
      if (repairSnap.docs.isEmpty) {
        final defaults = ['Size Change', 'Polishing', 'Chain Repair', 'Hook Repair', 'Clasp Repair', 'Stone Setting', 'Rhodium Plating', 'Engraving', 'Other'];
        for (final d in defaults) {
          await FirebaseFirestore.instance.collection('repair_types').add({
            'name': d,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        final reloaded = await FirebaseFirestore.instance
            .collection('repair_types')
            .orderBy('name')
            .get();
        repairs = reloaded.docs
            .map((doc) => doc.data()['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
      } else {
        repairs = repairSnap.docs
            .map((doc) => doc.data()['name']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
      }

      // Fetch customers
      final custSnap = await FirebaseFirestore.instance.collection('customers').get();
      final custs = custSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      custs.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));

      // Fetch suppliers
      final suppSnap = await FirebaseFirestore.instance.collection('suppliers').get();
      final supps = suppSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      supps.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));

      // Seed GST HSN codes
      await _seedGstHsnCodesIfNeeded();

      // Fetch GST HSN codes
      final hsnSnap = await FirebaseFirestore.instance.collection('gst_hsn_codes').get();
      final hsnList = hsnSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      hsnList.sort((a, b) => (a['code'] ?? '').toString().compareTo((b['code'] ?? '').toString()));

      setState(() {
        _itemNames = items;
        _bankNames = banks;
        _metalGroups = groups;
        _extraStyles = styles;
        _salesmen = salesmenList;
        _counters = countersList;
        _repairTypesList = repairs;
        _customerList = custs;
        _supplierList = supps;
        _gstHsnList = hsnList;
        _selectedCardBank = cardB;
        _selectedUpiBank = upiB;
      });
    } catch (e) {
      debugPrint('Error loading master data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _seedGstHsnCodesIfNeeded() async {
    final snap = await FirebaseFirestore.instance.collection('gst_hsn_codes').limit(1).get();
    if (snap.docs.isEmpty) {
      final initialCodes = [
        {
          'code': '7116',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Articles of natural or cultured pearls'
        },
        {
          'code': '7117',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Imitation jewellery'
        },
        {
          'code': '7118',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Coins'
        },
        {
          'code': '71181000',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Coins'
        },
        {
          'code': '998221',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Financial auditing services'
        },
        {
          'code': '998222',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Accounting and bookkeeping services'
        },
        {
          'code': '998313',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Information technology (IT) consulting'
        },
        {
          'code': '998412',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Fixed telephone services'
        },
        {
          'code': '998413',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Mobile telecommunications services'
        },
        {
          'code': '998441',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'News agency services'
        },
        {
          'code': '998533',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'General cleaning services'
        },
        {
          'code': '998722',
          'date': '01/07/2017',
          'igst': 18.000,
          'cgst': 9.000,
          'sgst': 9.000,
          'description': 'Repair services'
        },
        {
          'code': '998892',
          'date': '01/07/2017',
          'igst': 5.000,
          'cgst': 2.500,
          'sgst': 2.500,
          'description': 'Jewellery manufacturing services'
        },
        {
          'code': '7105',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Dust and powder of natural or synthetic precious or semi-precious stones'
        },
        {
          'code': '7106',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Silver (including silver plated with gold or platinum), unwrought or in semi-manufactured forms, or in powder form'
        },
        {
          'code': '7107',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Base metals clad with silver, not further worked than semi-manufactured'
        },
        {
          'code': '7108',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Gold (including gold plated with platinum) unwrought or in semi-manufactured forms, or in powder form'
        },
        {
          'code': '71081100',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Gold (including gold plated with platinum), powder'
        },
        {
          'code': '7109',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Base metals or silver, clad with gold, not further worked than semi-manufactured'
        },
        {
          'code': '7110',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Platinum, unwrought or in semi-manufactured forms, or in powder form'
        },
        {
          'code': '7111',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Base metals, silver or gold, clad with platinum, not further worked than semi-manufactured'
        },
        {
          'code': '7112',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Waste and scrap of precious metal or of metal clad with precious metal'
        },
        {
          'code': '7113',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Articles of jewellery and parts thereof, of precious metal or of metal clad with precious metal'
        },
        {
          'code': '7114',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Articles of goldsmiths\' or silversmiths\' wares and parts thereof, of precious metal or of metal clad with precious metal'
        },
        {
          'code': '7115',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Other articles of precious metal or of metal clad with precious metal'
        },
        {
          'code': '711311',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Of silver, whether or not plated or clad with other precious metal'
        },
        {
          'code': '711319',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Of other precious metal, whether or not plated or clad with precious metal'
        },
        {
          'code': '711411',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Of silver, whether or not plated or clad with other precious metal'
        },
        {
          'code': '711419',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Of other precious metal, whether or not plated or clad with precious metal'
        },
        {
          'code': '711420',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Of base metal clad with precious metal'
        },
        {
          'code': '711590',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Other'
        },
        {
          'code': '711719',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Other'
        },
        {
          'code': '711790',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Other'
        },
        {
          'code': '7101',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Pearls, natural or cultured, whether or not worked or graded but not strung, mounted or set'
        },
        {
          'code': '7102',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Diamonds, whether or not worked, but not mounted or set'
        },
        {
          'code': '7103',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Precious stones (other than diamonds) and semi-precious stones, whether or not worked or graded but not strung, mounted or set'
        },
        {
          'code': '7104',
          'date': '01/07/2017',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Synthetic or reconstructed precious or semi-precious stones, whether or not worked or graded but not strung, mounted or set'
        },
        {
          'code': '710310',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Unworked or simply sawn or roughly shaped'
        },
        {
          'code': '710391',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Ruby, sapphire and emeralds, worked'
        },
        {
          'code': '710399',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Other - Other precious or semi-precious stones, worked'
        },
        {
          'code': '710420',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Other, unworked or simply sawn or roughly shaped'
        },
        {
          'code': '710691',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Unwrought'
        },
        {
          'code': '710692',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Semi-manufactured'
        },
        {
          'code': '711011',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Unwrought or in powder form'
        },
        {
          'code': '711299',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Other'
        },
        {
          'code': '710110',
          'date': '01/04/2021',
          'igst': 3.000,
          'cgst': 1.500,
          'sgst': 1.500,
          'description': 'Natural pearls'
        },
        {
          'code': '710221',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Unworked or simply sawn or cleaved or bruted'
        },
        {
          'code': '710229',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Other - Industrial diamonds'
        },
        {
          'code': '710239',
          'date': '01/04/2021',
          'igst': 0.250,
          'cgst': 0.125,
          'sgst': 0.125,
          'description': 'Other - Non-Industrial diamonds'
        }
      ];

      final batch = FirebaseFirestore.instance.batch();
      for (final code in initialCodes) {
        final ref = FirebaseFirestore.instance.collection('gst_hsn_codes').doc();
        batch.set(ref, {
          ...code,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> _saveOption() async {
    setState(() => _isSaving = true);
    try {
      if (_activeTab == 0) {
        final val = _itemController.text.trim();
        if (val.isNotEmpty) {
          await _productRepo.saveItemName(val);
          _itemController.clear();
          _showToast('Item Name added successfully');
        }
      } else if (_activeTab == 1) {
        final val = _bankController.text.trim();
        if (val.isNotEmpty) {
          final exists = _bankNames.any((b) => b.toLowerCase() == val.toLowerCase());
          if (!exists) {
            await FirebaseFirestore.instance.collection('book_names').add({
              'name': val,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _bankController.clear();
            _showToast('Bank Name added successfully');
          } else {
            _showError('Bank Name already exists');
          }
        }
      } else if (_activeTab == 3) {
        final mId = _metalIdController.text.trim();
        final gName = _groupNameController.text.trim();
        if (mId.isNotEmpty && gName.isNotEmpty) {
          await _productRepo.saveMetalGroup(mId, gName, linkedRateId: _linkedRateId);
          _metalIdController.clear();
          _groupNameController.clear();
          setState(() => _linkedRateId = null);
          _showToast('Metal Group added successfully');
        }
      } else if (_activeTab == 4) {
        final val = _styleController.text.trim();
        if (val.isNotEmpty) {
          await _productRepo.saveExtraStyle(val);
          _styleController.clear();
          _showToast('Style Name added successfully');
        }
      } else if (_activeTab == 5) {
        final val = _salesmanController.text.trim();
        if (val.isNotEmpty) {
          await _productRepo.saveSalesman(val);
          _salesmanController.clear();
          _showToast('Salesman added successfully');
        }
      } else if (_activeTab == 6) {
        final val = _counterController.text.trim();
        if (val.isNotEmpty) {
          await _productRepo.saveCounter(val);
          _counterController.clear();
          _showToast('Counter added successfully');
        }
      } else if (_activeTab == 7) {
        final val = _repairTypeController.text.trim();
        if (val.isNotEmpty) {
          final exists = _repairTypesList.any((b) => b.toLowerCase() == val.toLowerCase());
          if (!exists) {
            await FirebaseFirestore.instance.collection('repair_types').add({
              'name': val,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _repairTypeController.clear();
            _showToast('Repair Type added successfully');
          } else {
            _showError('Repair Type already exists');
          }
        }
      } else if (_activeTab == 10) {
        final code = _hsnCodeController.text.trim();
        final date = _hsnDateController.text.trim();
        final igst = double.tryParse(_hsnIgstController.text.trim()) ?? 0.0;
        final cgst = double.tryParse(_hsnCgstController.text.trim()) ?? 0.0;
        final sgst = double.tryParse(_hsnSgstController.text.trim()) ?? 0.0;
        final desc = _hsnDescController.text.trim();

        if (code.isNotEmpty && date.isNotEmpty) {
          await FirebaseFirestore.instance.collection('gst_hsn_codes').add({
            'code': code,
            'date': date,
            'igst': igst,
            'cgst': cgst,
            'sgst': sgst,
            'description': desc,
            'createdAt': FieldValue.serverTimestamp(),
          });
          _hsnCodeController.clear();
          _hsnDateController.clear();
          _hsnIgstController.clear();
          _hsnCgstController.clear();
          _hsnSgstController.clear();
          _hsnDescController.clear();
          _showToast('GSTHSN Code added successfully');
        } else {
          _showError('Please enter at least GSTHSN Code and Applicable Date');
        }
      }
      await _loadAllData();
      widget.adminState?.notifyDropdownsUpdated();
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteOption(dynamic key1, [dynamic key2]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        title: const Text('Confirm Delete', style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "$key1"${key2 != null ? ' - "$key2"' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3E2723),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      if (_activeTab == 0) {
        await _productRepo.deleteItemName(key1);
        _showToast('Item Name deleted');
      } else if (_activeTab == 1) {
        final snap = await FirebaseFirestore.instance
            .collection('book_names')
            .where('name', isEqualTo: key1)
            .get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
        _showToast('Bank Name deleted');
      } else if (_activeTab == 3) {
        await _productRepo.deleteMetalGroup(key1, key2);
        _showToast('Metal Group deleted');
      } else if (_activeTab == 4) {
        await _productRepo.deleteExtraStyle(key1);
        _showToast('Style Name deleted');
      } else if (_activeTab == 5) {
        await _productRepo.deleteSalesman(key1);
        _showToast('Salesman deleted');
      } else if (_activeTab == 6) {
        await _productRepo.deleteCounter(key1);
        _showToast('Counter deleted');
      } else if (_activeTab == 7) {
        final snap = await FirebaseFirestore.instance
            .collection('repair_types')
            .where('name', isEqualTo: key1)
            .get();
        for (final doc in snap.docs) {
          await doc.reference.delete();
        }
        _showToast('Repair Type deleted');
      } else if (_activeTab == 8) {
        await FirebaseFirestore.instance.collection('customers').doc(key1).delete();
        _showToast('Customer deleted');
      } else if (_activeTab == 9) {
        await FirebaseFirestore.instance.collection('suppliers').doc(key1).delete();
        _showToast('Supplier deleted');
      } else if (_activeTab == 10) {
        await FirebaseFirestore.instance.collection('gst_hsn_codes').doc(key1).delete();
        _showToast('GSTHSN Code deleted');
      }
      await _loadAllData();
      widget.adminState?.notifyDropdownsUpdated();
    } catch (e) {
      _showError('Failed to delete: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF3E2723),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[900],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: const Color(0xFFFCFAF5),
      child: SizedBox(
        width: screenSize.width * 0.98,
        height: screenSize.height * 0.95,
        child: Column(
          children: [
            // Header (Matches Add Item Master header style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCA6F1E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFCA6F1E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add Master',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF3E2723),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF3E2723)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Sidebar and Content Area
            Expanded(
              child: Row(
                children: [
                  // Left sidebar tabs
                  Container(
                    width: 220,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAF2E9),
                      border: Border(right: BorderSide(color: Color(0xFFE5DDD0))),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      children: [
                        _buildSidebarTab(0, '🏷️  Item Names'),
                        _buildSidebarTab(1, '🏦  Bank Names'),
                        _buildSidebarTab(2, '⚙️  Prefix Setup'),
                        _buildSidebarTab(3, '🪙  Metal Groups'),
                        _buildSidebarTab(4, '🎨  Style Names'),
                        _buildSidebarTab(5, '👤  Salesmen'),
                        _buildSidebarTab(6, '🏪  Counters'),
                        _buildSidebarTab(7, '🛠️  Repair Types'),
                        _buildSidebarTab(8, '👥  Add Customer'),
                        _buildSidebarTab(9, '🏢  Add Supplier'),
                        _buildSidebarTab(10, '📄  GSTHSN Codes'),
                      ],
                    ),
                  ),

                  // Right Detail Area
                  Expanded(
                    child: Container(
                      color: Colors.white,
                      child: _activeTab == 2
                          ? const ClipRect(child: ItemPrefixView(isEmbedded: true))
                          : (_activeTab == 8 || _activeTab == 9
                              ? _buildPartyManagementPanel(isSupplier: _activeTab == 9)
                              : (_activeTab == 10
                                  ? _buildGstHsnManagementPanel()
                                  : _buildOptionManagementPanel())),
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

  Widget _buildSidebarTab(int index, String title) {
    final isSelected = _activeTab == index;
    final themeColor = const Color(0xFF3E2723);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = index;
            _searchQuery = '';
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? themeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF8D6E63),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionManagementPanel() {
    final themeColor = const Color(0xFF3E2723);
    String tabTitle = '';
    String helperText = '';
    Widget formFields = SizedBox.shrink();

    // Setup tab parameters
    if (_activeTab == 0) {
      tabTitle = 'Item Names Master';
      helperText = 'Manage items available in billing dropdowns (e.g. 916 KADA, Chain).';
      formFields = _buildSingleTextField('New Item Name', _itemController, 'e.g. 916 BRACELET');
    } else if (_activeTab == 1) {
      tabTitle = 'Bank Names Master';
      helperText = 'Manage banks available in billing bank selection dropdowns.';
      formFields = _buildSingleTextField('New Bank Name', _bankController, 'e.g. STATE BANK OF INDIA');
    } else if (_activeTab == 3) {
      tabTitle = 'Metal Groups Master';
      helperText = 'Manage metal karatages/types (e.g. 22KT, 18KT, Platinum).';
      formFields = Row(
        children: [
          Expanded(
            child: _buildTextFieldRaw('Metal ID (Short Code)', _metalIdController, 'e.g. 22KT'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildTextFieldRaw('Group Name (Label)', _groupNameController, 'e.g. 22 Karat Gold'),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildLinkedRateDropdown(),
          ),
        ],
      );
    } else if (_activeTab == 4) {
      tabTitle = 'Style Names Master';
      helperText = 'Manage extra style dropdown values (e.g. Antique, Matte).';
      formFields = _buildSingleTextField('New Style Name', _styleController, 'e.g. ANTIQUE DOTTED');
    } else if (_activeTab == 5) {
      tabTitle = 'Salesmen Master';
      helperText = 'Manage salesman accounts available in billing and transaction entries.';
      formFields = _buildSingleTextField('New Salesman Name', _salesmanController, 'e.g. Staff 4');
    } else if (_activeTab == 6) {
      tabTitle = 'Counters Master';
      helperText = 'Manage counter/shop numbers (e.g. C1, C2, CHAIN, RING).';
      formFields = _buildSingleTextField('New Counter Name', _counterController, 'e.g. C6');
    } else if (_activeTab == 7) {
      tabTitle = 'Repair Types Master';
      helperText = 'Manage repair types available in Alteration dropdowns.';
      formFields = _buildSingleTextField('New Repair Type', _repairTypeController, 'e.g. Laser Soldering');
    }

    // Filter list
    final List<dynamic> filteredList;
    if (_activeTab == 0) {
      filteredList = _itemNames.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_activeTab == 1) {
      filteredList = _bankNames.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_activeTab == 3) {
      filteredList = _metalGroups.where((e) {
        final id = e['metalId'] ?? '';
        final name = e['groupName'] ?? '';
        return id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    } else if (_activeTab == 4) {
      filteredList = _extraStyles.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_activeTab == 5) {
      filteredList = _salesmen.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_activeTab == 6) {
      filteredList = _counters.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_activeTab == 7) {
      filteredList = _repairTypesList.where((e) => e.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else {
      filteredList = [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
            color: Color(0xFFFCFAF5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tabTitle,
                style: const TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
              ),
              const SizedBox(height: 4),
              Text(
                helperText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
              ),
            ],
          ),
        ),

        // Add form
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF2E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBDCCB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: formFields),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _saveOption,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Option', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),

        // Options List, Search and Grid inside a Single bordered White Box
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5DDD0)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar inside the Box
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search existing options...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      fillColor: const Color(0xFFFCFAF5),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: themeColor)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grid of Options inside the Box
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)))
                        : filteredList.isEmpty
                            ? Center(
                                child: Text(
                                  _searchQuery.isEmpty ? 'No options added yet.' : 'No matches found.',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth;
                                  final crossAxisCount = width > 1100 ? 5 : (width > 800 ? 4 : (width > 550 ? 3 : 2));
                                  return GridView.builder(
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 4.5,
                                    ),
                                    itemCount: filteredList.length,
                                    itemBuilder: (context, idx) {
                                      final item = filteredList[idx];
                                      if (_activeTab == 3) {
                                        final mId = item['metalId'] ?? '';
                                        final gName = item['groupName'] ?? '';
                                        return _buildGridCard(mId, subtitle: gName, onDelete: () => _deleteOption(mId, gName));
                                      } else {
                                        return _buildGridCard(item.toString(), onDelete: () => _deleteOption(item));
                                      }
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_activeTab == 1) _buildPaymentMappingsCard(),
      ],
    );
  }

  Widget _buildSingleTextField(String label, TextEditingController controller, String hint) {
    return _buildTextFieldRaw(label, controller, hint);
  }

  Widget _buildTextFieldRaw(String label, TextEditingController controller, String hint) {
    final themeColor = const Color(0xFF3E2723);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF3E2723))),
          ),
        ),
      ],
    );
  }

  Widget _buildGridCard(String title, {String? subtitle, required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        border: Border.all(color: const Color(0xFFE5DDD0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF3E2723), fontSize: 13),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedRateDropdown() {
    final liveRates = widget.adminState?.liveRatesList ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Link to Rate Management',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8D6E63),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5DDD0)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _linkedRateId,
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('None', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ),
              icon: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.arrow_drop_down, color: Color(0xFF8D6E63)),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('None', style: TextStyle(fontSize: 13)),
                  ),
                ),
                ...liveRates.map((rate) {
                  return DropdownMenuItem<String>(
                    value: rate.id,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(rate.name, style: const TextStyle(fontSize: 13)),
                    ),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _linkedRateId = val;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _savePaymentMappings() async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('bank_mappings')
          .set({
        'cardBank': _selectedCardBank ?? '',
        'upiBank': _selectedUpiBank ?? '',
      });
    } catch (e) {
      debugPrint('Error saving payment mappings: $e');
    }
  }

  Widget _buildPaymentMappingsCard() {
    // Ensure selected bank exists in _bankNames list or reset to null
    final cardValue = _bankNames.contains(_selectedCardBank) ? _selectedCardBank : null;
    final upiValue = _bankNames.contains(_selectedUpiBank) ? _selectedUpiBank : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5DDD0)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Default Bank Account Mapping",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
            ),
            const SizedBox(height: 4),
            const Text(
              "Automatically route Card and UPI payments to the selected default bank accounts.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Card Payments Default Bank",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFAF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5DDD0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: cardValue,
                            hint: const Text("Select default bank for Card", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8D6E63)),
                            items: _bankNames.map((bank) {
                              return DropdownMenuItem<String>(
                                value: bank,
                                child: Text(bank),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCardBank = val;
                              });
                              _savePaymentMappings();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "UPI Payments Default Bank",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF8D6E63)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFCFAF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE5DDD0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: upiValue,
                            hint: const Text("Select default bank for UPI", style: TextStyle(fontSize: 12, color: Colors.grey)),
                            isExpanded: true,
                            style: const TextStyle(fontSize: 12, color: Colors.black87),
                            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF8D6E63)),
                            items: _bankNames.map((bank) {
                              return DropdownMenuItem<String>(
                                value: bank,
                                child: Text(bank),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedUpiBank = val;
                              });
                              _savePaymentMappings();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyManagementPanel({required bool isSupplier}) {
    final themeColor = const Color(0xFF3E2723);
    final partyTitle = isSupplier ? 'Supplier Master' : 'Customer Master';
    final partyHelper = isSupplier
        ? 'Manage suppliers/vendors, GST numbers, contact details, and credit terms.'
        : 'Manage customers, contact numbers, family head details, and credit limits.';
    final rawList = isSupplier ? _supplierList : _customerList;

    final filteredList = rawList.where((p) {
      final q = _searchQuery.toLowerCase();
      final name = (p['name'] ?? p['familyHead'] ?? '').toString().toLowerCase();
      final code = (p['customerCode'] ?? p['supplierCode'] ?? p['code'] ?? '').toString().toLowerCase();
      final mob = (p['mobileNo1'] ?? p['mobile'] ?? p['phone'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? p['state'] ?? '').toString().toLowerCase();
      final gst = (p['gstNo'] ?? p['gstin'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || mob.contains(q) || city.contains(q) || gst.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
            color: Color(0xFFFCFAF5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    partyTitle,
                    style: const TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    partyHelper,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  final res = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (ctx) => AddCustomerDialog(isSupplier: isSupplier),
                  );
                  if (res != null) {
                    await _loadAllData();
                    widget.adminState?.notifyDropdownsUpdated();
                  }
                },
                icon: Icon(isSupplier ? Icons.business_center_rounded : Icons.person_add_rounded, size: 18),
                label: Text(
                  isSupplier ? 'Add New Supplier' : 'Add New Customer',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Search Bar & Table Container
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5DDD0)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search ${isSupplier ? "suppliers" : "customers"} by name, code, mobile, city, GST...',
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8D6E63), size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFFCFAF5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF2E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEBDCCB)),
                        ),
                        child: Text(
                          'Total: ${filteredList.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3E2723)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Data Table
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(isSupplier ? Icons.business_center_outlined : Icons.person_off_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No matching ${isSupplier ? "suppliers" : "customers"} found'
                                      : 'No ${isSupplier ? "suppliers" : "customers"} registered yet',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5DDD0)),
                            itemBuilder: (context, idx) {
                              final party = filteredList[idx];
                              final id = party['id']?.toString() ?? '';
                              final code = (party['customerCode'] ?? party['supplierCode'] ?? party['code'] ?? '').toString();
                              final name = (party['name'] ?? party['familyHead'] ?? 'Unnamed').toString();
                              final mob = (party['mobileNo1'] ?? party['mobile'] ?? party['phone'] ?? '—').toString();
                              final city = (party['city'] ?? party['state'] ?? '—').toString();
                              final gst = (party['gstNo'] ?? party['gstin'] ?? '—').toString();

                              return Container(
                                color: idx.isEven ? const Color(0xFFFCFAF5) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    // Code
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        code.isNotEmpty ? code : '—',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCA6F1E)),
                                      ),
                                    ),
                                    // Name
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        name,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Mobile
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        mob,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    // City / State
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        city,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    // GST
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        gst,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ),
                                    // Actions
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF2E7D32)),
                                          tooltip: 'Edit Details',
                                          onPressed: () async {
                                            final res = await showDialog<Map<String, dynamic>>(
                                              context: context,
                                              builder: (ctx) => AddCustomerDialog(
                                                isSupplier: isSupplier,
                                                initialData: party,
                                              ),
                                            );
                                            if (res != null) {
                                              await _loadAllData();
                                              widget.adminState?.notifyDropdownsUpdated();
                                            }
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          tooltip: 'Delete',
                                          onPressed: () => _deleteOption(id, name),
                                        ),
                                      ],
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
          ),
        ),
      ],
    );
  }

  Widget _buildGstHsnManagementPanel() {
    final themeColor = const Color(0xFF3E2723);
    final filteredList = _gstHsnList.where((p) {
      final q = _searchQuery.toLowerCase();
      final code = (p['code'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      return code.contains(q) || desc.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5DDD0))),
            color: Color(0xFFFCFAF5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'GST/HSN Codes Master',
                style: TextStyle(fontFamily: 'serif', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage HSN/SAC codes, applicable tax rates (IGST, CGST, SGST), and descriptions.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8D6E63)),
              ),
            ],
          ),
        ),

        // Form to Add New GST/HSN Code
        Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF2E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEBDCCB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextFieldRaw('GSTHSN Code', _hsnCodeController, 'e.g. 7113'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Applicable Date',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hsnDateController,
                        readOnly: true,
                        onTap: () => _selectHsnDate(context),
                        decoration: InputDecoration(
                          hintText: 'DD/MM/YYYY',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          fillColor: Colors.white,
                          filled: true,
                          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF8D6E63)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3E2723))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IGST %', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hsnIgstController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (val) {
                          final parsed = double.tryParse(val) ?? 0.0;
                          final half = parsed / 2.0;
                          _hsnCgstController.text = half.toStringAsFixed(3);
                          _hsnSgstController.text = half.toStringAsFixed(3);
                        },
                        decoration: InputDecoration(
                          hintText: '3.0',
                          hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                          fillColor: Colors.white,
                          filled: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF3E2723))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFieldRaw('CGST %', _hsnCgstController, '1.5'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextFieldRaw('SGST %', _hsnSgstController, '1.5'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: _buildTextFieldRaw('Description', _hsnDescController, 'e.g. Articles of jewellery'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isSaving ? null : _saveOption,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),

        // Search Bar & Table Container
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5DDD0)),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Search HSN codes by code or description...',
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF8D6E63), size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: const Color(0xFFFCFAF5),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5DDD0))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF2E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEBDCCB)),
                        ),
                        child: Text(
                          'Total: ${filteredList.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3E2723)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Table Headers
                  Container(
                    color: const Color(0xFFFAF7F2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            'GSTHSN Code',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            'Applicable Date',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'IGST %',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'CGST %',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            'SGST %',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Description',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Actions',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3E2723)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE5DDD0)),

                  // Data Rows
                  Expanded(
                    child: filteredList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No GSTHSN codes found',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5DDD0)),
                            itemBuilder: (context, idx) {
                              final hsn = filteredList[idx];
                              final id = hsn['id']?.toString() ?? '';
                              final code = (hsn['code'] ?? '—').toString();
                              final date = (hsn['date'] ?? '—').toString();
                              final igst = (hsn['igst'] ?? 0.0).toString();
                              final cgst = (hsn['cgst'] ?? 0.0).toString();
                              final sgst = (hsn['sgst'] ?? 0.0).toString();
                              final desc = (hsn['description'] ?? '—').toString();

                              return Container(
                                color: idx.isEven ? const Color(0xFFFCFAF5) : Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        code,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFCA6F1E)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        date,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        igst,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        cgst,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 80,
                                      child: Text(
                                        sgst,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        desc,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 60,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _deleteOption(id, code),
                                        ),
                                      ),
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
          ),
        ),
      ],
    );
  }

  Future<void> _selectHsnDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _hsnDateController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }
}
