import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../services/local_db_service.dart';
import '../services/sync_service.dart';

const _brown = Color(0xFF3E2723);
const _brownLight = Color(0xFF5D4037);
const _border = Color(0xFFE5DDD0);
const _bg = Color(0xFFF9F6F0);

class AddCustomerDialog extends StatefulWidget {
  final bool isSupplier;
  final Map<String, dynamic>? initialData;
  final Function(Map<String, dynamic> data)? onSaved;
  const AddCustomerDialog({super.key, this.isSupplier = false, this.initialData, this.onSaved});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  // Left Column Controllers
  final _codeCtrl = TextEditingController();
  final _familyHeadCtrl = TextEditingController();
  final _blockNoCtrl = TextEditingController();
  final _buildingNameCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'COIMBATORE');
  final _zipCodeCtrl = TextEditingController();
  final _stateCtrl = TextEditingController(text: 'Tamil Nadu');
  final _countryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      final d = widget.initialData!;
      _codeCtrl.text = (widget.isSupplier ? (d['supplierCode'] ?? '') : (d['customerCode'] ?? '')).toString();
      _familyHeadCtrl.text = (d['familyHead'] ?? d['name'] ?? '').toString();
      _blockNoCtrl.text = (d['blockNo'] ?? '').toString();
      _buildingNameCtrl.text = (d['buildingName'] ?? '').toString();
      _streetCtrl.text = (d['street'] ?? d['address'] ?? '').toString();
      _areaCtrl.text = (d['area'] ?? '').toString();
      if ((d['city'] ?? '').toString().isNotEmpty) {
        _cityCtrl.text = d['city'].toString();
      }
      _zipCodeCtrl.text = (d['zipCode'] ?? d['postalCode'] ?? '').toString();
      if ((d['state'] ?? '').toString().isNotEmpty) {
        _stateCtrl.text = d['state'].toString();
      }
      _countryCtrl.text = (d['country'] ?? '').toString();
      _contactName1Ctrl.text = (d['contactName1'] ?? d['contactName'] ?? '').toString();
      _contactName2Ctrl.text = (d['contactName2'] ?? '').toString();
      _mobileNo1Ctrl.text = (d['mobileNo1'] ?? d['phone'] ?? '').toString();
      _mobileNo2Ctrl.text = (d['mobileNo2'] ?? '').toString();
      _faxNo1Ctrl.text = (d['faxNo1'] ?? '').toString();
      _faxNo2Ctrl.text = (d['faxNo2'] ?? '').toString();
      _email1Ctrl.text = (d['email1'] ?? d['email'] ?? '').toString();
      _email2Ctrl.text = (d['email2'] ?? '').toString();
      _reference1Ctrl.text = (d['reference1'] ?? '').toString();
      _reference2Ctrl.text = (d['reference2'] ?? '').toString();
      _birthDateCtrl.text = (d['birthDate'] ?? '').toString();
      _anniversaryCtrl.text = (d['anniversary'] ?? '').toString();
      _spouseNameCtrl.text = (d['spouseName'] ?? '').toString();
      _spouseBirthDateCtrl.text = (d['spouseBirthDate'] ?? '').toString();
      _childName1Ctrl.text = (d['childName1'] ?? '').toString();
      _childBirthDate1Ctrl.text = (d['childBirthDate1'] ?? '').toString();
      _childName2Ctrl.text = (d['childName2'] ?? '').toString();
      _childBirthDate2Ctrl.text = (d['childBirthDate2'] ?? '').toString();
      _gstinCtrl.text = (d['gstin'] ?? d['vatNumber'] ?? '').toString();
      _gstinDateCtrl.text = (d['gstinDate'] ?? '').toString();
      _panCtrl.text = (d['pan'] ?? d['panNumber'] ?? '').toString();
      _collectorateCtrl.text = (d['collectorate'] ?? '').toString();
      _msmeNoCtrl.text = (d['msmeNo'] ?? '').toString();
      _msmeActivityCtrl.text = (d['msmeActivity'] ?? 'None').toString();
      _msmeTypeCtrl.text = (d['msmeType'] ?? 'None').toString();
      _creditLimitCtrl.text = (d['creditLimit'] ?? '0').toString();
      _creditDaysCtrl.text = (d['creditDays'] ?? '0').toString();
      _isCompositionScheme = d['isCompositionScheme'] == true;

      _docBase64Map['photoBase64'] = (d['photoBase64'] ?? '').toString();
      _docBase64Map['panCardBase64'] = (d['panCardBase64'] ?? '').toString();
      _docBase64Map['aadhaarBase64'] = (d['aadhaarBase64'] ?? '').toString();
      _docBase64Map['drivingLicenceBase64'] = (d['drivingLicenceBase64'] ?? '').toString();
      _docBase64Map['electionCardBase64'] = (d['electionCardBase64'] ?? '').toString();
      _docBase64Map['passportBase64'] = (d['passportBase64'] ?? '').toString();

      _photoCtrl.text = _docBase64Map['photoBase64']!.isNotEmpty ? 'photograph.jpg' : '';
      _panCardDocCtrl.text = _docBase64Map['panCardBase64']!.isNotEmpty ? 'pancard.jpg' : '';
      _aadhaarDocCtrl.text = _docBase64Map['aadhaarBase64']!.isNotEmpty ? 'aadhaar.jpg' : '';
      _drivingLicenceCtrl.text = _docBase64Map['drivingLicenceBase64']!.isNotEmpty ? 'driving_licence.jpg' : '';
      _electionCardCtrl.text = _docBase64Map['electionCardBase64']!.isNotEmpty ? 'election_card.jpg' : '';
      _passportCtrl.text = _docBase64Map['passportBase64']!.isNotEmpty ? 'passport.jpg' : '';

      if (_docBase64Map['photoBase64']!.isNotEmpty) {
        try {
          _photoBytes = base64Decode(_docBase64Map['photoBase64']!);
        } catch (_) {}
      }
    } else {
      _fetchNextCode();
    }
  }

  Future<void> _fetchNextCode() async {
    try {
      final collection = widget.isSupplier ? 'suppliers' : 'customers';
      final codeField = widget.isSupplier ? 'supplierCode' : 'customerCode';
      final snap = await FirebaseFirestore.instance.collection(collection).get();
      int maxCode = 0;
      for (final doc in snap.docs) {
        final val = doc.data()[codeField];
        if (val != null) {
          final cleanVal = val.toString().replaceAll(RegExp(r'\D'), '');
          final codeInt = int.tryParse(cleanVal);
          if (codeInt != null && codeInt > maxCode) {
            maxCode = codeInt;
          }
        }
      }
      if (mounted) {
        setState(() {
          _codeCtrl.text = (maxCode + 1).toString();
        });
      }
    } catch (e) {
      debugPrint('Error fetching next code: $e');
      if (mounted) {
        setState(() {
          _codeCtrl.text = '1';
        });
      }
    }
  }
  
  final _contactName1Ctrl = TextEditingController();
  final _contactName2Ctrl = TextEditingController();
  final _mobileNo1Ctrl = TextEditingController();
  final _mobileNo2Ctrl = TextEditingController();
  final _faxNo1Ctrl = TextEditingController();
  final _faxNo2Ctrl = TextEditingController();
  final _email1Ctrl = TextEditingController();
  final _email2Ctrl = TextEditingController();
  final _reference1Ctrl = TextEditingController();
  final _reference2Ctrl = TextEditingController();
  
  final _birthDateCtrl = TextEditingController();
  final _anniversaryCtrl = TextEditingController();
  final _spouseNameCtrl = TextEditingController();
  final _spouseBirthDateCtrl = TextEditingController();
  final _childName1Ctrl = TextEditingController();
  final _childBirthDate1Ctrl = TextEditingController();
  final _childName2Ctrl = TextEditingController();
  final _childBirthDate2Ctrl = TextEditingController();

  bool _isCompositionScheme = false;
  
   final ImagePicker _picker = ImagePicker();
  Uint8List? _photoBytes;
  final Map<String, String> _docBase64Map = {};

  // Right Column Controllers
  final _gstinCtrl = TextEditingController();
  final _gstinDateCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _collectorateCtrl = TextEditingController();
  final _msmeNoCtrl = TextEditingController();
  final _msmeActivityCtrl = TextEditingController(text: 'None');
  final _msmeTypeCtrl = TextEditingController(text: 'None');
  final _creditLimitCtrl = TextEditingController(text: '0');
  final _creditDaysCtrl = TextEditingController(text: '0');
  
  final _photoCtrl = TextEditingController();
  final _panCardDocCtrl = TextEditingController();
  final _aadhaarDocCtrl = TextEditingController();
  final _drivingLicenceCtrl = TextEditingController();
  final _electionCardCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    _familyHeadCtrl.dispose();
    _blockNoCtrl.dispose();
    _buildingNameCtrl.dispose();
    _streetCtrl.dispose();
    _areaCtrl.dispose();
    _cityCtrl.dispose();
    _zipCodeCtrl.dispose();
    _stateCtrl.dispose();
    _countryCtrl.dispose();
    _contactName1Ctrl.dispose();
    _contactName2Ctrl.dispose();
    _mobileNo1Ctrl.dispose();
    _mobileNo2Ctrl.dispose();
    _faxNo1Ctrl.dispose();
    _faxNo2Ctrl.dispose();
    _email1Ctrl.dispose();
    _email2Ctrl.dispose();
    _reference1Ctrl.dispose();
    _reference2Ctrl.dispose();
    _birthDateCtrl.dispose();
    _anniversaryCtrl.dispose();
    _spouseNameCtrl.dispose();
    _spouseBirthDateCtrl.dispose();
    _childName1Ctrl.dispose();
    _childBirthDate1Ctrl.dispose();
    _childName2Ctrl.dispose();
    _childBirthDate2Ctrl.dispose();
    
    _gstinCtrl.dispose();
    _gstinDateCtrl.dispose();
    _panCtrl.dispose();
    _collectorateCtrl.dispose();
    _msmeNoCtrl.dispose();
    _msmeActivityCtrl.dispose();
    _msmeTypeCtrl.dispose();
    _creditLimitCtrl.dispose();
    _creditDaysCtrl.dispose();
    _photoCtrl.dispose();
    _panCardDocCtrl.dispose();
    _aadhaarDocCtrl.dispose();
    _drivingLicenceCtrl.dispose();
    _electionCardCtrl.dispose();
    _passportCtrl.dispose();
    super.dispose();
  }

  Widget _buildTextField(String label, {TextEditingController? controller, double labelWidth = 100}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _brownLight)),
          ),
          Expanded(
            child: SizedBox(
              height: 24,
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _brown)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithSearch(String label, {TextEditingController? controller, double labelWidth = 100}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _brownLight)),
          ),
          Expanded(
            child: SizedBox(
              height: 24,
              child: TextField(
                controller: controller,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _brown)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              onPressed: () {},
              child: const Text('Search', style: TextStyle(fontSize: 11)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDocRow(String label, {TextEditingController? controller, double labelWidth = 100, VoidCallback? onBrowse}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: 12, color: _brownLight)),
          ),
          Expanded(
            child: SizedBox(
              height: 24,
              child: TextField(
                controller: controller,
                readOnly: true,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              onPressed: onBrowse ?? () {},
              child: const Text('Browse', style: TextStyle(fontSize: 11)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHalfRow(String label1, Widget field1, String label2, Widget field2, {double labelWidth1 = 100, double labelWidth2 = 80}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth1,
            child: Text(label1, style: const TextStyle(fontSize: 12, color: _brownLight)),
          ),
          Expanded(
            child: SizedBox(height: 24, child: field1),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: labelWidth2,
            child: Text(label2, style: const TextStyle(fontSize: 12, color: _brownLight)),
          ),
          Expanded(
            child: SizedBox(height: 24, child: field2),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(widget.isSupplier ? "Supplier Code" : "Customer Code", controller: _codeCtrl),
        _buildTextFieldWithSearch("Family Head", controller: _familyHeadCtrl),
        _buildTextField("Block No.", controller: _blockNoCtrl),
        _buildTextField("Building Name", controller: _buildingNameCtrl),
        _buildTextField("Street", controller: _streetCtrl),
        _buildTextField("Area", controller: _areaCtrl),
        _buildHalfRow(
          "City", _buildSimpleDropdown(_cityCtrl, ['COIMBATORE', 'CHENNAI']),
          "Zip Code", _buildSimpleTextField(_zipCodeCtrl)
        ),
        _buildHalfRow(
          "State", _buildSimpleDropdown(_stateCtrl, ['Tamil Nadu', 'Kerala', 'Karnataka']),
          "Country", _buildSimpleTextField(_countryCtrl)
        ),
        const Divider(),
        _buildTextField("Contact Name 1", controller: _contactName1Ctrl),
        _buildTextField("Contact Name 2", controller: _contactName2Ctrl),
        _buildHalfRow(
          "Mobile No. 1", _buildSimpleTextField(_mobileNo1Ctrl),
          "Mobile No. 2", _buildSimpleTextField(_mobileNo2Ctrl)
        ),
        _buildHalfRow(
          "Fax No. 1", _buildSimpleTextField(_faxNo1Ctrl),
          "Fax No. 2", _buildSimpleTextField(_faxNo2Ctrl)
        ),
        _buildTextField("E-Mail 1", controller: _email1Ctrl),
        _buildTextField("E-Mail 2", controller: _email2Ctrl),
        _buildTextFieldWithSearch("Reference 1", controller: _reference1Ctrl),
        _buildTextFieldWithSearch("Reference 2", controller: _reference2Ctrl),
        const Divider(),
        _buildHalfRow(
          "Birth Date", _buildSimpleTextField(_birthDateCtrl),
          "Anniversary", _buildSimpleTextField(_anniversaryCtrl)
        ),
        _buildHalfRow(
          "Spouse Name", _buildSimpleTextField(_spouseNameCtrl),
          "Birth Date", _buildSimpleTextField(_spouseBirthDateCtrl)
        ),
        _buildHalfRow(
          "Child Name 1", _buildSimpleTextField(_childName1Ctrl),
          "Birth Date", _buildSimpleTextField(_childBirthDate1Ctrl)
        ),
        _buildHalfRow(
          "Child Name 2", _buildSimpleTextField(_childName2Ctrl),
          "Birth Date", _buildSimpleTextField(_childBirthDate2Ctrl)
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: Checkbox(
                value: _isCompositionScheme,
                onChanged: (val) {
                  setState(() => _isCompositionScheme = val ?? false);
                },
                activeColor: _brown,
              ),
            ),
            const SizedBox(width: 8),
            const Text("Registered Under Composition Scheme", style: TextStyle(fontSize: 12)),
          ],
        )
      ],
    );
  }

  Future<void> _pickDocument(TextEditingController ctrl, {bool isPhoto = false}) async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 800);
      if (file != null) {
        setState(() {
          ctrl.text = file.name;
        });
        final bytes = await file.readAsBytes();
        final base64Str = base64Encode(bytes);

        String key = '';
        if (ctrl == _photoCtrl) key = 'photoBase64';
        if (ctrl == _panCardDocCtrl) key = 'panCardBase64';
        if (ctrl == _aadhaarDocCtrl) key = 'aadhaarBase64';
        if (ctrl == _drivingLicenceCtrl) key = 'drivingLicenceBase64';
        if (ctrl == _electionCardCtrl) key = 'electionCardBase64';
        if (ctrl == _passportCtrl) key = 'passportBase64';

        if (key.isNotEmpty) {
          _docBase64Map[key] = base64Str;
        }

        if (isPhoto) {
          setState(() {
            _photoBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking document: $e");
    }
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHalfRow(
          "GSTIN/UIN No.", _buildSimpleTextField(_gstinCtrl),
          "Date", _buildSimpleTextField(_gstinDateCtrl),
          labelWidth1: 100, labelWidth2: 40
        ),
        _buildTextField("IT Pan No.", controller: _panCtrl, labelWidth: 100),
        _buildHalfRow(
          "Collectorate", _buildSimpleTextField(_collectorateCtrl),
          "MSME No.", _buildSimpleTextField(_msmeNoCtrl),
          labelWidth1: 100, labelWidth2: 70
        ),
        _buildHalfRow(
          "MSME Major Activity", _buildSimpleDropdown(_msmeActivityCtrl, ['None', 'Manufacturing', 'Services']),
          "MSME Type", _buildSimpleDropdown(_msmeTypeCtrl, ['None', 'Micro', 'Small', 'Medium']),
          labelWidth1: 100, labelWidth2: 70
        ),
        _buildHalfRow(
          "Credit Limit", _buildSimpleTextField(_creditLimitCtrl),
          "Credit Days", _buildSimpleTextField(_creditDaysCtrl),
          labelWidth1: 100, labelWidth2: 70
        ),
        const SizedBox(height: 8),
        _buildDocRow("Photograph", controller: _photoCtrl, onBrowse: () => _pickDocument(_photoCtrl, isPhoto: true)),
        _buildDocRow("Pan Card", controller: _panCardDocCtrl, onBrowse: () => _pickDocument(_panCardDocCtrl)),
        _buildDocRow("Aadhaar Card", controller: _aadhaarDocCtrl, onBrowse: () => _pickDocument(_aadhaarDocCtrl)),
        _buildDocRow("Driving Licence", controller: _drivingLicenceCtrl, onBrowse: () => _pickDocument(_drivingLicenceCtrl)),
        _buildDocRow("Election Card", controller: _electionCardCtrl, onBrowse: () => _pickDocument(_electionCardCtrl)),
        _buildDocRow("Passport", controller: _passportCtrl, onBrowse: () => _pickDocument(_passportCtrl)),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
              ),
              alignment: Alignment.center,
              child: _photoBytes != null 
                  ? Image.memory(_photoBytes!, fit: BoxFit.cover)
                  : const Text("No image data", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: _isSaving ? null : _saveToFirestore,
              icon: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle, color: Colors.green),
              label: Text(_isSaving ? "Saving..." : "Ok (F2)"),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.grey),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.cancel, color: Colors.red),
              label: const Text("Cancel"),
            ),
          ],
        )
      ],
    );
  }

  bool _isSaving = false;

  Future<void> _saveToFirestore() async {
    final displayName = _familyHeadCtrl.text.trim().isNotEmpty
        ? _familyHeadCtrl.text.trim()
        : (_contactName1Ctrl.text.trim().isNotEmpty
            ? _contactName1Ctrl.text.trim()
            : (widget.isSupplier ? 'New Supplier' : 'New Customer'));

    final Map<String, dynamic> data = {
      if (widget.isSupplier) 'supplierCode': _codeCtrl.text.trim(),
      if (!widget.isSupplier) 'customerCode': _codeCtrl.text.trim(),
      'name': displayName,
      'familyHead': _familyHeadCtrl.text.trim(),
      'blockNo': _blockNoCtrl.text.trim(),
      'buildingName': _buildingNameCtrl.text.trim(),
      'street': _streetCtrl.text.trim(),
      'area': _areaCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'zipCode': _zipCodeCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'contactName1': _contactName1Ctrl.text.trim(),
      'contactName2': _contactName2Ctrl.text.trim(),
      'mobileNo1': _mobileNo1Ctrl.text.trim(),
      'mobileNo2': _mobileNo2Ctrl.text.trim(),
      'faxNo1': _faxNo1Ctrl.text.trim(),
      'faxNo2': _faxNo2Ctrl.text.trim(),
      'email1': _email1Ctrl.text.trim(),
      'email2': _email2Ctrl.text.trim(),
      'reference1': _reference1Ctrl.text.trim(),
      'reference2': _reference2Ctrl.text.trim(),
      'birthDate': _birthDateCtrl.text.trim(),
      'anniversary': _anniversaryCtrl.text.trim(),
      'spouseName': _spouseNameCtrl.text.trim(),
      'spouseBirthDate': _spouseBirthDateCtrl.text.trim(),
      'childName1': _childName1Ctrl.text.trim(),
      'childBirthDate1': _childBirthDate1Ctrl.text.trim(),
      'childName2': _childName2Ctrl.text.trim(),
      'childBirthDate2': _childBirthDate2Ctrl.text.trim(),
      'isCompositionScheme': _isCompositionScheme,
      'gstin': _gstinCtrl.text.trim(),
      'gstinDate': _gstinDateCtrl.text.trim(),
      'pan': _panCtrl.text.trim(),
      'collectorate': _collectorateCtrl.text.trim(),
      'msmeNo': _msmeNoCtrl.text.trim(),
      'msmeActivity': _msmeActivityCtrl.text.trim(),
      'msmeType': _msmeTypeCtrl.text.trim(),
      'creditLimit': double.tryParse(_creditLimitCtrl.text.trim()) ?? 0.0,
      'creditDays': int.tryParse(_creditDaysCtrl.text.trim()) ?? 0,
      'photoBase64': _docBase64Map['photoBase64'] ?? '',
      'panCardBase64': _docBase64Map['panCardBase64'] ?? '',
      'aadhaarBase64': _docBase64Map['aadhaarBase64'] ?? '',
      'drivingLicenceBase64': _docBase64Map['drivingLicenceBase64'] ?? '',
      'electionCardBase64': _docBase64Map['electionCardBase64'] ?? '',
      'passportBase64': _docBase64Map['passportBase64'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    setState(() => _isSaving = true);
    try {
      final collection = widget.isSupplier ? 'suppliers' : 'customers';
      
      // Save locally instead of directly to Firebase
      await LocalDbService().insertEntry(collection, data);
      SyncService().syncNow(); // Try to sync immediately if online
      
      // Since it's offline-first, we just mock a temporary ID for local UI
      final fakeId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      data['id'] = widget.initialData?['id']?.toString() ?? fakeId;

      if (mounted) {
        final label = widget.isSupplier ? 'Supplier' : 'Customer';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $label "$displayName" saved locally! It will sync automatically when online.'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSaved?.call(data);
        Navigator.of(context).pop(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSimpleTextField(TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _brown)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSimpleDropdown(TextEditingController ctrl, List<String> items) {
    final cleanItems = items.toSet().toList();
    final safeValue = (ctrl.text.isNotEmpty && cleanItems.contains(ctrl.text)) ? ctrl.text : (cleanItems.isNotEmpty ? cleanItems.first : null);
    return DropdownButtonFormField<String>(
      initialValue: safeValue,
      icon: const Icon(Icons.arrow_drop_down, size: 16),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(2), borderSide: const BorderSide(color: _border)),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 12, color: Colors.black87),
      items: cleanItems.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 11)))).toList(),
      onChanged: (val) {
        if (val != null) ctrl.text = val;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.isSupplier ? "Address Detail (Supplier)" : "Address Detail (Customer)",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _brown),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: _buildLeftColumn(),
                      ),
                    ),
                  ),
                  Container(width: 1, color: _border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: _buildRightColumn(),
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
}
