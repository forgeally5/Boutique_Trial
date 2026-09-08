// customize_reports_view.dart
// K Customize Reports — A (Report Designer / Template Settings)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../report_shared.dart';

const _br  = Color(0xFF3E2723);
const _brL = Color(0xFF6D4C41);
const _bdr = Color(0xFFE5DDD0);

class ReportDesignerSettingsView extends StatefulWidget {
  final ValueChanged<String>? onReportSelected;
  const ReportDesignerSettingsView({super.key, this.onReportSelected});
  @override State<ReportDesignerSettingsView> createState() => _ReportDesignerSettingsState();
}

class _ReportDesignerSettingsState extends State<ReportDesignerSettingsView> {
  bool _loading = true;
  bool _saving = false;

  // Form controllers
  final _businessNameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  
  String _selectedThemeColor = 'Brown'; // 'Brown', 'Navy', 'Emerald', 'Slate'
  bool _showLogo = true;
  bool _includeSignatureBlock = true;

  final Map<String, Color> _themes = {
    'Brown': const Color(0xFF3E2723),
    'Navy': const Color(0xFF1A237E),
    'Emerald': const Color(0xFF1B5E20),
    'Slate': const Color(0xFF263238),
  };

  @override void initState() {
    super.initState();
    _loadSettings();
  }

  @override void dispose() {
    _businessNameCtrl.dispose();
    _subtitleCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _gstCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final doc = await FirebaseFirestore.instance.collection('report_designer_settings').doc('default').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _businessNameCtrl.text = data['businessName']?.toString() ?? 'TRILOK JEWELLERS';
        _subtitleCtrl.text = data['subtitle']?.toString() ?? 'Dealers in Gold, Silver & Diamond Ornaments';
        _addressCtrl.text = data['address']?.toString() ?? '123, Cross Cut Road, Gandhipuram, Coimbatore - 641012';
        _phoneCtrl.text = data['phone']?.toString() ?? '+91 98765 43210';
        _emailCtrl.text = data['email']?.toString() ?? 'contact@trilokjewellers.com';
        _gstCtrl.text = data['gstNo']?.toString() ?? '33AAAAA1111A1Z1';
        _footerCtrl.text = data['footerText']?.toString() ?? 'Thank you for your business! Items once sold cannot be taken back.';
        _selectedThemeColor = data['themeColor']?.toString() ?? 'Brown';
        _showLogo = data['showLogo'] ?? true;
        _includeSignatureBlock = data['includeSignatureBlock'] ?? true;
      } else {
        // Load default values
        _businessNameCtrl.text = 'TRILOK JEWELLERS';
        _subtitleCtrl.text = 'Dealers in Gold, Silver & Diamond Ornaments';
        _addressCtrl.text = '123, Cross Cut Road, Gandhipuram, Coimbatore - 641012';
        _phoneCtrl.text = '+91 98765 43210';
        _emailCtrl.text = 'contact@trilokjewellers.com';
        _gstCtrl.text = '33AAAAA1111A1Z1';
        _footerCtrl.text = 'Thank you for your business! Items once sold cannot be taken back.';
        _selectedThemeColor = 'Brown';
        _showLogo = true;
        _includeSignatureBlock = true;
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('Error loading designer settings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _saving = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('report_designer_settings').doc('default');
      await docRef.set({
        'businessName': _businessNameCtrl.text.trim(),
        'subtitle': _subtitleCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'gstNo': _gstCtrl.text.trim(),
        'footerText': _footerCtrl.text.trim(),
        'themeColor': _selectedThemeColor,
        'showLogo': _showLogo,
        'includeSignatureBlock': _includeSignatureBlock,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report designer settings saved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving designer settings: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.palette_rounded, size: 17, color: _br),
              const SizedBox(width: 8),
              buildTitleDropdown(
                context: context,
                currentTitle: 'Report Designer / Template Settings',
                onSelected: (newTitle) {
                  widget.onReportSelected?.call(newTitle);
                },
                textColor: _br,
                fontSize: 14,
                bold: true,
              ),
              const Spacer(),
              if (_saving)
                const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _br),
                )
              else
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label: const Text('Save Settings', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _br,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: _bdr),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _br))
              : _buildMainContent(),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Settings form (Left Pane)
        Expanded(
          flex: 4,
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Header Configurations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _br)),
                  const SizedBox(height: 12),
                  _buildFormText('Business / Company Name', _businessNameCtrl),
                  _buildFormText('Subtitle / Business Slogan', _subtitleCtrl),
                  _buildFormText('Store Address Details', _addressCtrl, maxLines: 2),
                  Row(
                    children: [
                      Expanded(child: _buildFormText('Contact Phone', _phoneCtrl)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildFormText('Contact Email', _emailCtrl)),
                    ],
                  ),
                  _buildFormText('GSTIN / Tax Registration No', _gstCtrl),
                  
                  const SizedBox(height: 20),
                  const Text('Theme & Design Options', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _br)),
                  const SizedBox(height: 12),
                  _buildThemeSelector(),
                  const SizedBox(height: 8),
                  
                  SwitchListTile(
                    title: const Text('Show Corporate Logo on Header', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    dense: true,
                    activeThumbColor: _br,
                    value: _showLogo,
                    onChanged: (v) => setState(() => _showLogo = v),
                  ),
                  SwitchListTile(
                    title: const Text('Include Authorized Signature Block', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    dense: true,
                    activeThumbColor: _br,
                    value: _includeSignatureBlock,
                    onChanged: (v) => setState(() => _includeSignatureBlock = v),
                  ),
                  
                  const SizedBox(height: 15),
                  const Text('Footer Configurations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _br)),
                  const SizedBox(height: 12),
                  _buildFormText('Terms & Footer Note', _footerCtrl, maxLines: 2),
                ],
              ),
            ),
          ),
        ),
        
        // Vertical Divider
        const VerticalDivider(width: 1, color: _bdr),
        
        // Live Preview Pane (Right Pane)
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFFF9F7F3),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.visibility_rounded, size: 14, color: _brL),
                    SizedBox(width: 6),
                    Text('LIVE REPORT LAYOUT PREVIEW', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _brL, letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildPrintPreviewCard()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormText(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 12),
            onChanged: (_) => setState(() {}), // Trigger live preview update
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _bdr), borderRadius: BorderRadius.circular(6)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _br, width: 1.4), borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Report Highlight Color', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _brL)),
        const SizedBox(height: 6),
        Row(
          children: _themes.keys.map((name) {
            final col = _themes[name]!;
            final sel = _selectedThemeColor == name;
            return GestureDetector(
              onTap: () => setState(() => _selectedThemeColor = name),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? col : Colors.white,
                  border: Border.all(color: sel ? col : _bdr),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: sel ? Colors.white : col, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrintPreviewCard() {
    final tCol = _themes[_selectedThemeColor] ?? _br;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: _bdr),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Theme colored top band
            Container(height: 5, color: tCol),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showLogo) ...[
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: tCol.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: tCol.withAlpha(80)),
                          ),
                          child: Icon(Icons.star_rounded, color: tCol, size: 24),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _businessNameCtrl.text.toUpperCase(),
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: tCol, fontFamily: 'serif'),
                            ),
                            if (_subtitleCtrl.text.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(_subtitleCtrl.text, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 4),
                            Text(_addressCtrl.text, style: TextStyle(fontSize: 8, color: Colors.grey.shade700)),
                            const SizedBox(height: 2),
                            Text(
                              'Phone: ${_phoneCtrl.text}  |  Email: ${_emailCtrl.text}',
                              style: TextStyle(fontSize: 8, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('GSTIN: ${_gstCtrl.text.toUpperCase()}', style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
                      const Text('ORIGINAL COPY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: tCol.withAlpha(60)),
                ],
              ),
            ),
            
            // Report title & Metadata banner
            Container(
              color: tCol.withAlpha(12),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('SALES REGISTER REPORT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tCol)),
                  const Text('FY: 2026 - 2027  |  Date: 16-Aug-2026', style: TextStyle(fontSize: 8, color: Colors.black87)),
                ],
              ),
            ),
            
            // Mock Data Table
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table Header
                    Container(
                      color: Colors.grey.shade100,
                      padding: const EdgeInsets.all(6),
                      child: Row(
                        children: [
                          const SizedBox(width: 20, child: Text('#', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                          const Expanded(child: Text('Item Name', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 40, child: Text('Pcs', textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 50, child: Text('Net Wt', textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold))),
                          SizedBox(width: 60, child: Text('Value (₹)', textAlign: TextAlign.right, style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: tCol))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: _bdr),
                    
                    // Table Body rows
                    _buildMockRow('1', 'Gold Kada Bracelet 22K', '1', '24.120 g', '1,63,500.00'),
                    _buildMockRow('2', 'Diamond Stud Earrings 18K', '2', '4.150 g', '75,000.00'),
                    _buildMockRow('3', 'Silver Pooja plate 925', '1', '120.000 g', '12,500.00'),
                    
                    const Spacer(),
                    
                    // Table Totals
                    const Divider(height: 1, color: _bdr),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      child: Row(
                        children: [
                          const SizedBox(width: 20),
                          const Expanded(child: Text('TOTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 40, child: Text('4', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 50, child: Text('148.270 g', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                          SizedBox(width: 60, child: Text('2,51,000.00', textAlign: TextAlign.right, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tCol))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Signature & Footer block
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  if (_includeSignatureBlock) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prepared By: admin', style: TextStyle(fontSize: 7, color: Colors.grey)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(width: 70, height: 1, color: Colors.grey.shade400),
                            const SizedBox(height: 2),
                            const Text('Authorized Signatory', style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Container(height: 0.5, color: Colors.grey.shade300),
                  const SizedBox(height: 6),
                  Text(
                    _footerCtrl.text.isEmpty ? 'Thank you!' : _footerCtrl.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 7, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockRow(String id, String item, String pcs, String wt, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      child: Row(
        children: [
          SizedBox(width: 20, child: Text(id, style: const TextStyle(fontSize: 7, color: Colors.black54))),
          Expanded(child: Text(item, style: const TextStyle(fontSize: 7, color: Colors.black87, fontWeight: FontWeight.w500))),
          SizedBox(width: 40, child: Text(pcs, textAlign: TextAlign.right, style: const TextStyle(fontSize: 7, color: Colors.black87))),
          SizedBox(width: 50, child: Text(wt, textAlign: TextAlign.right, style: const TextStyle(fontSize: 7, color: Colors.black87))),
          SizedBox(width: 60, child: Text(val, textAlign: TextAlign.right, style: const TextStyle(fontSize: 7, color: Colors.black87))),
        ],
      ),
    );
  }
}
