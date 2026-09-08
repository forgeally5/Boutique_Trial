import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/item_prefix.dart';
import '../services/item_prefix_service.dart';
import '../products/repositories/product_repository.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF6D4C41);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFF8F9FA);
const _redBorder = Color(0xFFE53935);

enum _PrefixFormMode { add, view, edit }

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN VIEW  — shows the prefix table only
// ═══════════════════════════════════════════════════════════════════════════════
class ItemPrefixView extends StatefulWidget {
  const ItemPrefixView({super.key, this.isEmbedded = false});
  final bool isEmbedded;

  @override
  State<ItemPrefixView> createState() => _ItemPrefixViewState();
}

class _ItemPrefixViewState extends State<ItemPrefixView> {
  final ItemPrefixService _service = ItemPrefixService();

  List<ItemPrefix> _existingPrefixes = [];
  bool _loadingExisting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingPrefixes();
  }

  Future<void> _loadExistingPrefixes() async {
    setState(() => _loadingExisting = true);
    _existingPrefixes = await _service.getAllItemPrefixes();
    if (mounted) setState(() => _loadingExisting = false);
  }

  // ── Open form dialog ───────────────────────────────────────────────────────
  Future<void> _openForm(_PrefixFormMode mode, [ItemPrefix? prefix]) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PrefixFormDialog(
        mode: mode,
        prefix: prefix,
        existingPrefixes: _existingPrefixes,
        onSaved: _loadExistingPrefixes,
      ),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────
  Future<void> _confirmDelete(ItemPrefix p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 22),
            SizedBox(width: 8),
            Text('Delete Prefix',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown)),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            children: [
              const TextSpan(text: 'Are you sure you want to delete prefix '),
              TextSpan(
                text: '"${p.prefix}"',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _brown),
              ),
              const TextSpan(text: '?\n\nThis action cannot be undone.'),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: OutlinedButton.styleFrom(
                foregroundColor: _brownLight, side: const BorderSide(color: _border)),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Delete'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
          ),
        ],
      ),
    );

    if (confirm == true && p.id != null) {
      try {
        await _service.deleteItemPrefix(p.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Prefix "${p.prefix}" deleted.'),
            backgroundColor: const Color(0xFF4E342E),
            duration: const Duration(seconds: 2),
          ));
        }
        _loadExistingPrefixes();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD — table only
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ───────────────────────────────────────────────────────
          Row(
            children: [
              if (!widget.isEmbedded)
                const Text('Item Prefix Master',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: _brown)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _openForm(_PrefixFormMode.add),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add New'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Prefix table ─────────────────────────────────────────────────
          Expanded(child: _buildPrefixTable()),
        ],
      ),
    );
  }

  Widget _buildPrefixTable() {
    if (_loadingExisting) {
      return const Center(
          child: CircularProgressIndicator(color: _brownLight));
    }

    if (_existingPrefixes.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_outline, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No prefixes yet. Click "Add New" to create one.',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Text('Existing Prefixes',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: _brown)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _brown.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${_existingPrefixes.length}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold, color: _brown)),
            ),
            const Spacer(),
            Text('Click to view  •  Double-click to edit',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontStyle: FontStyle.italic)),
          ],
        ),
        const SizedBox(height: 8),

        // Table header
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF3EDE8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: _border),
          ),
          child: _tableHeaderRow(),
        ),

        // Scrollable rows
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _border),
                right: BorderSide(color: _border),
                bottom: BorderSide(color: _border),
              ),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: ListView.separated(
              itemCount: _existingPrefixes.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: _border.withValues(alpha: 0.5)),
              itemBuilder: (_, i) => _buildRow(_existingPrefixes[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tableHeaderRow() {
    const style = TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: _brownLight);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: Row(
        children: [
          _hdr('Prefix', 120, style),
          _hdr('Item Name', 180, style),
          _hdr('Group', 80, style),
          _hdr('Reusable', 80, style),
          _hdr('Description', 0, style, flex: true),
          const SizedBox(width: 96),
        ],
      ),
    );
  }

  Widget _hdr(String label, double w, TextStyle style, {bool flex = false}) {
    final child = Text(label, style: style);
    return flex
        ? Expanded(child: child)
        : SizedBox(width: w, child: child);
  }

  Widget _buildRow(ItemPrefix p) {
    return GestureDetector(
      onTap: () => _openForm(_PrefixFormMode.view, p),
      onDoubleTap: () => _openForm(_PrefixFormMode.edit, p),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            // Prefix
            SizedBox(
              width: 120,
              child: Text(p.prefix,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFFBCAAA4))),
            ),
            // Item name
            SizedBox(
              width: 180,
              child: Text(p.itemName,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                  overflow: TextOverflow.ellipsis),
            ),
            // Group badge
            SizedBox(
              width: 80,
              child: p.groupName.isEmpty
                  ? const SizedBox()
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCA6F1E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(p.groupName,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFCA6F1E))),
                    ),
            ),
            // Reusable
            SizedBox(
              width: 80,
              child: Text(p.reusable,
                  style: TextStyle(
                      fontSize: 12,
                      color: p.reusable == 'Yes'
                          ? const Color(0xFF2E7D32)
                          : Colors.black54)),
            ),
            // Description
            Expanded(
              child: Text(
                  p.prefixDescription.isEmpty ? '—' : p.prefixDescription,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                  overflow: TextOverflow.ellipsis),
            ),
            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBtn(Icons.visibility_outlined, 'View', const Color(0xFF1565C0),
                    () => _openForm(_PrefixFormMode.view, p)),
                const SizedBox(width: 4),
                _iconBtn(Icons.edit_outlined, 'Edit', const Color(0xFFE65100),
                    () => _openForm(_PrefixFormMode.edit, p)),
                const SizedBox(width: 4),
                _iconBtn(Icons.delete_outline, 'Delete', const Color(0xFFE53935),
                    () => _confirmDelete(p)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  FORM DIALOG  — add / view / edit
// ═══════════════════════════════════════════════════════════════════════════════
class _PrefixFormDialog extends StatefulWidget {
  const _PrefixFormDialog({
    required this.mode,
    required this.existingPrefixes,
    required this.onSaved,
    this.prefix,
  });

  final _PrefixFormMode mode;
  final ItemPrefix? prefix;
  final List<ItemPrefix> existingPrefixes;
  final VoidCallback onSaved;

  @override
  State<_PrefixFormDialog> createState() => _PrefixFormDialogState();
}

class _PrefixFormDialogState extends State<_PrefixFormDialog> {
  final ItemPrefixService _service = ItemPrefixService();
  late _PrefixFormMode _mode;

  // Toggles
  bool _showWeightOptions = false;
  bool _showTagWeight = false;

  // Dropdowns
  String _itemName = '';
  String _counterNo = 'C1';
  String _allowChangeCounterNo = 'No';
  String _reusable = 'No';
  String _groupName = '';

  // Controllers
  final TextEditingController _prefixCtrl = TextEditingController();
  final TextEditingController _startFromCtrl = TextEditingController(text: '1');
  final TextEditingController _endNoCtrl = TextEditingController(text: '0');
  final TextEditingController _tagWeightCtrl = TextEditingController(text: '0.000');
  final TextEditingController _prefixDescCtrl = TextEditingController();

  bool _isSaving = false;
  bool _prefixDuplicate = false;
  String? _editingId;

  List<MetalGroup> _metalGroups = [...MetalGroup.predefined];
  List<String> _itemNameOptions = [];
  List<String> _counterOptions = [];

  bool get _isReadOnly => _mode == _PrefixFormMode.view;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _loadItemNames();
    _loadCounters();
    _loadMetalGroups();
    _prefixCtrl.addListener(_onPrefixChanged);
    if (widget.prefix != null) {
      _populateFromPrefix(widget.prefix!);
    }
  }

  @override
  void dispose() {
    _prefixCtrl.removeListener(_onPrefixChanged);
    _prefixCtrl.dispose();
    _startFromCtrl.dispose();
    _endNoCtrl.dispose();
    _tagWeightCtrl.dispose();
    _prefixDescCtrl.dispose();
    super.dispose();
  }

  void _onPrefixChanged() {
    if (_mode == _PrefixFormMode.edit) {
      if (_prefixDuplicate) setState(() => _prefixDuplicate = false);
      return;
    }
    final typed = _prefixCtrl.text.trim().toLowerCase();
    if (typed.isEmpty) {
      if (_prefixDuplicate) setState(() => _prefixDuplicate = false);
      return;
    }
    final isDup = widget.existingPrefixes
        .any((p) => p.prefix.trim().toLowerCase() == typed);
    if (isDup != _prefixDuplicate) setState(() => _prefixDuplicate = isDup);
  }

  void _populateFromPrefix(ItemPrefix p) {
    if (p.itemName.isNotEmpty && !_itemNameOptions.contains(p.itemName)) {
      _itemNameOptions.add(p.itemName);
    }
    if (p.counterNo.isNotEmpty && !_counterOptions.contains(p.counterNo)) {
      _counterOptions.add(p.counterNo);
    }
    final groupExists = _metalGroups.any(
        (g) => g.metalId.toUpperCase() == p.groupName.toUpperCase());
    if (p.groupName.isNotEmpty && !groupExists) {
      _metalGroups.add(
          MetalGroup(metalId: p.groupName, groupName: p.groupName));
    }
    _editingId = p.id;
    _itemName = p.itemName;
    _counterNo = p.counterNo.isNotEmpty ? p.counterNo : 'C1';
    _allowChangeCounterNo =
        p.allowChangeCounterNo.isNotEmpty ? p.allowChangeCounterNo : 'No';
    _reusable = p.reusable.isNotEmpty ? p.reusable : 'No';
    _groupName = p.groupName;
    _showWeightOptions = p.netWtAccessible;
    _showTagWeight = p.reqOtherWeight;
    _prefixCtrl.text = p.prefix;
    _startFromCtrl.text = p.startFrom;
    _endNoCtrl.text = p.endNo;
    _tagWeightCtrl.text = p.tagWeight;
    _prefixDescCtrl.text = p.prefixDescription;
  }

  Future<void> _loadItemNames() async {
    try {
      final names = await ProductRepository().getUniqueItemNames();
      if (mounted) {
        setState(() {
          for (final n in names) {
            if (!_itemNameOptions.contains(n)) _itemNameOptions.add(n);
          }
          if (_itemNameOptions.isEmpty) {
            _itemNameOptions = ['916 KADA', '916 CHAIN', '916 RING'];
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCounters() async {
    try {
      final list = await ProductRepository().getUniqueCounters();
      if (mounted) {
        setState(() {
          for (final c in list) {
            if (!_counterOptions.contains(c)) _counterOptions.add(c);
          }
          if (_counterOptions.isEmpty) {
            _counterOptions = ['C1', 'C2', 'C3'];
          }
          if (!_counterOptions.contains(_counterNo)) {
            _counterNo = _counterOptions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMetalGroups() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('metal_groups_master')
          .get();
      if (snap.docs.isNotEmpty) {
        final custom = snap.docs.map((d) {
          final data = d.data();
          return MetalGroup(
            metalId: data['metalId']?.toString() ?? '',
            groupName: data['groupName']?.toString() ?? '',
          );
        }).where((g) => g.metalId.isNotEmpty).toList();
        final seen = <String>{};
        final combined = <MetalGroup>[];
        for (final g in [...MetalGroup.predefined, ...custom]) {
          if (seen.add(g.metalId)) combined.add(g);
        }
        if (mounted) setState(() => _metalGroups = combined);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefixText = _prefixCtrl.text.trim();
    if (prefixText.isEmpty) {
      _snack('Please enter a prefix name', Colors.red);
      return;
    }
    if (_itemName.isEmpty) {
      _snack('Please select an item name', Colors.red);
      return;
    }
    if (_groupName.isEmpty) {
      _snack('Please select a group name', Colors.red);
      return;
    }

    if (_mode == _PrefixFormMode.add) {
      final dup = widget.existingPrefixes.any(
          (p) => p.prefix.trim().toLowerCase() == prefixText.toLowerCase());
      if (dup) {
        setState(() => _prefixDuplicate = true);
        _snack('Prefix "$prefixText" already exists.', Colors.red.shade700);
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final ip = ItemPrefix(
        itemName: _itemName,
        prefix: prefixText,
        type: 'Automatically',
        pieces: '1',
        counterNo: _counterNo,
        reqOtherWeight: _showTagWeight,
        reqDesignNo: false,
        reqHuid: false,
        netWtAccessible: _showWeightOptions,
        reqDiamondMarkup: false,
        reqLabourMarkup: false,
        allowChangeCounterNo: _allowChangeCounterNo,
        startFrom: _startFromCtrl.text,
        endNo: _endNoCtrl.text,
        qty: '1',
        reusable: _reusable,
        inputPcsReq: 'No',
        groupName: _groupName,
        tagWeight: _tagWeightCtrl.text,
        allowChangeDiamond: 'No',
        allowChangeLabour: 'No',
        prefixDescription: _prefixDescCtrl.text,
        pcsName: '',
      );

      if (_mode == _PrefixFormMode.edit && _editingId != null) {
        await _service.updateItemPrefix(_editingId!, ip);
        _snack('Prefix "$prefixText" updated!', const Color(0xFF2E7D32));
      } else {
        await ProductRepository().saveItemName(_itemName);
        await _service.addItemPrefix(ip);
        _snack('Prefix "$prefixText" saved!', const Color(0xFF2E7D32));
      }

      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _snack('Error: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIALOG BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Title + colours per mode
    String title;
    Color headerColor;
    IconData headerIcon;
    switch (_mode) {
      case _PrefixFormMode.view:
        title = 'View Prefix';
        headerColor = const Color(0xFF1565C0);
        headerIcon = Icons.visibility_outlined;
        break;
      case _PrefixFormMode.edit:
        title = 'Edit Prefix';
        headerColor = const Color(0xFFE65100);
        headerIcon = Icons.edit_outlined;
        break;
      case _PrefixFormMode.add:
        title = 'Add New Prefix';
        headerColor = _brown;
        headerIcon = Icons.add_circle_outline;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 780,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Dialog header ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(headerIcon, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  if (_mode == _PrefixFormMode.view) ...[
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _mode = _PrefixFormMode.edit),
                      icon: const Icon(Icons.edit_outlined, size: 15, color: Colors.white70),
                      label: const Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ] else
                    const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable form body ───────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isReadOnly)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 14, color: Color(0xFF1565C0)),
                            SizedBox(width: 8),
                            Text('Read-only — double-click a field or tap Edit to modify.',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF1565C0))),
                          ],
                        ),
                      ),
                    // Two-column layout
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fr('Item Name', _buildItemNameDropdown()),
                              _fr('Prefix', _buildPrefixField()),
                              _fr('Counter No.', _buildDropdown(
                                _counterOptions.isNotEmpty
                                    ? _counterOptions
                                    : ['C1', 'C2', 'C3'],
                                _counterOptions.contains(_counterNo)
                                    ? _counterNo
                                    : (_counterOptions.isNotEmpty
                                        ? _counterOptions.first
                                        : _counterNo),
                                (v) { if (v != null && !_isReadOnly) setState(() => _counterNo = v); },
                              )),
                              _fr('Allow Change Counter No.', _buildDropdown(
                                ['Yes', 'No'],
                                _allowChangeCounterNo,
                                (v) { if (v != null && !_isReadOnly) setState(() => _allowChangeCounterNo = v); },
                              )),
                              const SizedBox(height: 8),
                              _buildWeightToggle(),
                              const SizedBox(height: 8),
                              _buildTagWeightToggle(),
                              if (_showTagWeight) ...[
                                const SizedBox(height: 10),
                                _fr('Tag Weight', _buildTextField(controller: _tagWeightCtrl)),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 28),
                        // Right
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fr('Start From', _buildTextField(controller: _startFromCtrl)),
                              _fr('End No', _buildTextField(controller: _endNoCtrl)),
                              _fr('Reusable', _buildDropdown(
                                ['No', 'Yes'],
                                _reusable,
                                (v) { if (v != null && !_isReadOnly) setState(() => _reusable = v); },
                              )),
                              _fr('Group Name', _buildMetalGroupDropdown()),
                              _fr('Prefix Description', _buildTextField(controller: _prefixDescCtrl)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Action bar ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(top: BorderSide(color: _border)),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _brownLight,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12)),
                    child: const Text('Close'),
                  ),
                  if (!_isReadOnly) ...[
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_isSaving
                          ? (_mode == _PrefixFormMode.edit ? 'Updating…' : 'Saving…')
                          : (_mode == _PrefixFormMode.edit ? 'Update' : 'Save')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _mode == _PrefixFormMode.edit
                            ? const Color(0xFFE65100)
                            : _brown,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form helpers ───────────────────────────────────────────────────────────
  Widget _buildWeightToggle() {
    return Row(
      children: [
        SizedBox(
          height: 26,
          width: 26,
          child: Checkbox(
            value: _showWeightOptions,
            onChanged: _isReadOnly ? null : (v) => setState(() => _showWeightOptions = v!),
            activeColor: _brown,
            side: const BorderSide(color: _brownLight),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Display Gross and Net Weight',
            style: TextStyle(fontSize: 12, color: _brownLight)),
      ],
    );
  }

  Widget _buildTagWeightToggle() {
    return Row(
      children: [
        SizedBox(
          height: 26,
          width: 26,
          child: Checkbox(
            value: _showTagWeight,
            onChanged: _isReadOnly ? null : (v) => setState(() => _showTagWeight = v!),
            activeColor: _brown,
            side: const BorderSide(color: _brownLight),
          ),
        ),
        const SizedBox(width: 8),
        const Text('Tag Weight',
            style: TextStyle(fontSize: 12, color: _brownLight)),
      ],
    );
  }

  Widget _fr(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: _brownLight, fontWeight: FontWeight.w500)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildPrefixField() {
    return SizedBox(
      height: 36,
      child: TextFormField(
        controller: _prefixCtrl,
        readOnly: _isReadOnly,
        style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          fillColor: _isReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          hintText: 'Enter prefix...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: _prefixDuplicate ? _redBorder : _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: _prefixDuplicate ? _redBorder : _border,
                  width: _prefixDuplicate ? 1.5 : 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                  color: _prefixDuplicate ? _redBorder : _brown, width: 1.5)),
          suffixIcon: _prefixDuplicate
              ? const Icon(Icons.warning_amber_rounded, color: _redBorder, size: 18)
              : null,
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller}) {
    return SizedBox(
      height: 36,
      child: TextFormField(
        controller: controller,
        readOnly: _isReadOnly,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        decoration: InputDecoration(
          fillColor: _isReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
          filled: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _brown)),
        ),
      ),
    );
  }

  Widget _buildItemNameDropdown() {
    final opts = _itemNameOptions.isNotEmpty
        ? _itemNameOptions
        : ['916 KADA', '916 CHAIN', '916 RING'];
    return SizedBox(
      height: 36,
      child: IgnorePointer(
        ignoring: _isReadOnly,
        child: DropdownButtonFormField<String>(
          initialValue: _itemName.isEmpty ? null : (opts.contains(_itemName) ? _itemName : null),
          hint: const Text('-- Select --', style: TextStyle(fontSize: 13, color: Colors.grey)),
          icon: Icon(Icons.arrow_drop_down, color: _isReadOnly ? Colors.grey.shade400 : _brownLight),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          dropdownColor: Colors.white,
          isExpanded: true,
          decoration: InputDecoration(
            fillColor: _isReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
          ),
          onChanged: (v) { if (v != null && !_isReadOnly) setState(() => _itemName = v); },
          items: opts.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
        ),
      ),
    );
  }

  Widget _buildMetalGroupDropdown() {
    final items = _metalGroups.isNotEmpty ? _metalGroups : MetalGroup.predefined;
    String? selectedVal;
    if (_groupName.isNotEmpty) {
      try {
        final match = items.firstWhere((g) =>
            g.metalId.toUpperCase() == _groupName.toUpperCase() ||
            g.groupName.toUpperCase() == _groupName.toUpperCase());
        selectedVal = match.metalId;
      } catch (_) {}
    }
    return SizedBox(
      height: 36,
      child: IgnorePointer(
        ignoring: _isReadOnly,
        child: DropdownButtonFormField<String>(
          initialValue: selectedVal,
          hint: const Text('-- Select --', style: TextStyle(fontSize: 13, color: Colors.grey)),
          icon: Icon(Icons.arrow_drop_down, color: _isReadOnly ? Colors.grey.shade400 : _brownLight),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          dropdownColor: Colors.white,
          isExpanded: true,
          decoration: InputDecoration(
            fillColor: _isReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: _border)),
          ),
          onChanged: (v) { if (v != null && !_isReadOnly) setState(() => _groupName = v); },
          items: items.map((g) {
            return DropdownMenuItem<String>(
              value: g.metalId,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCA6F1E).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(g.metalId,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCA6F1E))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(g.groupName, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDropdown(
      List<String> items, String value, ValueChanged<String?> onChanged) {
    final selected =
        items.contains(value) ? value : (items.isNotEmpty ? items.first : null);
    return SizedBox(
      height: 36,
      child: IgnorePointer(
        ignoring: _isReadOnly,
        child: DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down,
              color: _isReadOnly ? Colors.grey.shade400 : _brownLight),
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          items: items
              .map((e) => DropdownMenuItem(
                  value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            fillColor: _isReadOnly ? const Color(0xFFF5F5F5) : Colors.white,
            filled: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: _border)),
          ),
        ),
      ),
    );
  }
}
