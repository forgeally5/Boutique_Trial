import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Hostinger Subdomain Base URL
  static const String defaultBaseUrl = 'https://api.ritumitasrentaljewels.com';
  String baseUrl = defaultBaseUrl;

  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=UTF-8',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  // ─── AUTH ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth.php?action=login');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      _authToken = data['data']['token'];
      return data['data'];
    }
    throw Exception(data['message'] ?? 'Login failed');
  }

  Future<List<dynamic>> getAllUsers() async {
    final url = Uri.parse('$baseUrl/auth.php?action=all');
    final res = await http.get(url, headers: _headers);
    final data = jsonDecode(res.body);
    return (data['data'] as List?) ?? [];
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    final url = Uri.parse('$baseUrl/auth.php?action=create');
    final res = await http.post(url, headers: _headers, body: jsonEncode(userData));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to create user');
    }
  }

  // ─── PRODUCTS ────────────────────────────────────────────────────────
  Future<List<Product>> getProducts({
    String? category,
    String? status,
    String? search,
  }) async {
    final qParams = <String, String>{};
    if (category != null && category != 'All Categories') qParams['category'] = category;
    if (status != null && status != 'All Statuses') qParams['status'] = status;
    if (search != null && search.isNotEmpty) qParams['search'] = search;

    final uri = Uri.parse('$baseUrl/products.php').replace(queryParameters: qParams);
    final res = await http.get(uri, headers: _headers);
    final json = jsonDecode(res.body);

    if (json['success'] == true && json['data'] is List) {
      return (json['data'] as List).map((map) {
        return Product(
          tagId: map['tag_id'] ?? '',
          name: map['name'] ?? '',
          category: map['category'] ?? '',
          deity: map['deity'] ?? '',
          material: map['material'] ?? '',
          size: map['size'] ?? '',
          status: map['status'] ?? 'In Stock',
          vendor: map['vendor'] ?? '',
          notes: map['notes'] ?? '',
          pricingType: map['pricing_type'] ?? 'Quantity-Based',
          grossWeight: (map['gross_weight'] as num?)?.toDouble() ?? 0.0,
          netWeight: (map['net_weight'] as num?)?.toDouble() ?? 0.0,
          weightUnit: map['weight_unit'] ?? 'g',
          ratePerGram: (map['rate_per_gram'] as num?)?.toDouble() ?? 0.0,
          makingCharges: (map['making_charges'] as num?)?.toDouble() ?? 0.0,
          quantity: (map['quantity'] as num?)?.toInt() ?? 0,
          issueQuantity: (map['issue_quantity'] as num?)?.toInt() ?? 0,
          reservedQuantity: (map['reserved_quantity'] as num?)?.toInt() ?? 0,
          unit: map['unit'] ?? 'piece',
          mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
          sellingPrice: (map['selling_price'] as num?)?.toDouble() ?? 0.0,
          discountValue: (map['discount_value'] as num?)?.toDouble() ?? 0.0,
          discountType: map['discount_type'] ?? '%',
          finalPrice: (map['final_price'] as num?)?.toDouble() ?? 0.0,
          gstRate: (map['gst_rate'] as num?)?.toDouble() ?? 0.0,
          isFestivalStock: map['is_festival_stock'] == 1 || map['is_festival_stock'] == true,
          isReserved: map['is_reserved'] == 1 || map['is_reserved'] == true,
          reservedFor: map['reserved_for'] ?? '',
          imageUrl: map['image_url'] ?? '',
          rawJson: (map['raw_json'] as Map<String, dynamic>?) ?? map,
        );
      }).toList();
    }
    return [];
  }

  Future<void> saveProduct(Product product) async {
    final uri = Uri.parse('$baseUrl/products.php?action=create');
    final payload = {
      'tagId': product.tagId,
      'name': product.name,
      'category': product.category,
      'deity': product.deity,
      'material': product.material,
      'size': product.size,
      'status': product.status,
      'vendor': product.vendor,
      'notes': product.notes,
      'pricingType': product.pricingType,
      'grossWeight': product.grossWeight,
      'netWeight': product.netWeight,
      'weightUnit': product.weightUnit,
      'ratePerGram': product.ratePerGram,
      'makingCharges': product.makingCharges,
      'quantity': product.quantity,
      'issueQuantity': product.issueQuantity,
      'reservedQuantity': product.reservedQuantity,
      'unit': product.unit,
      'mrp': product.mrp,
      'sellingPrice': product.sellingPrice,
      'discountValue': product.discountValue,
      'discountType': product.discountType,
      'finalPrice': product.finalPrice,
      'gstRate': product.gstRate,
      'isFestivalStock': product.isFestivalStock,
      'isReserved': product.isReserved,
      'reservedFor': product.reservedFor,
      'imageUrl': product.imageUrl,
      'addedDate': product.addedDate?.toIso8601String(),
    };

    final res = await http.post(uri, headers: _headers, body: jsonEncode(payload));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to save product');
    }
  }

  Future<void> updateProduct(Product product) async {
    final uri = Uri.parse('$baseUrl/products.php?action=update');
    final payload = {
      'tagId': product.tagId,
      'name': product.name,
      'category': product.category,
      'deity': product.deity,
      'material': product.material,
      'size': product.size,
      'status': product.status,
      'vendor': product.vendor,
      'notes': product.notes,
      'pricingType': product.pricingType,
      'grossWeight': product.grossWeight,
      'netWeight': product.netWeight,
      'weightUnit': product.weightUnit,
      'ratePerGram': product.ratePerGram,
      'makingCharges': product.makingCharges,
      'quantity': product.quantity,
      'issueQuantity': product.issueQuantity,
      'reservedQuantity': product.reservedQuantity,
      'unit': product.unit,
      'mrp': product.mrp,
      'sellingPrice': product.sellingPrice,
      'discountValue': product.discountValue,
      'discountType': product.discountType,
      'finalPrice': product.finalPrice,
      'gstRate': product.gstRate,
      'isFestivalStock': product.isFestivalStock,
      'isReserved': product.isReserved,
      'reservedFor': product.reservedFor,
      'imageUrl': product.imageUrl,
    };

    final res = await http.post(uri, headers: _headers, body: jsonEncode(payload));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteProduct(String tagId) async {
    final uri = Uri.parse('$baseUrl/products.php?action=delete&tagId=${Uri.encodeComponent(tagId)}');
    final res = await http.post(uri, headers: _headers);
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete product');
    }
  }

  // ─── BILLING ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBills({
    String? customer,
    bool pendingOnly = false,
    String? startDate,
    String? endDate,
  }) async {
    final qParams = <String, String>{};
    if (customer != null && customer.isNotEmpty) qParams['customer'] = customer;
    if (pendingOnly) qParams['pendingOnly'] = 'true';
    if (startDate != null) qParams['startDate'] = startDate;
    if (endDate != null) qParams['endDate'] = endDate;

    final uri = Uri.parse('$baseUrl/bills.php').replace(queryParameters: qParams);
    final res = await http.get(uri, headers: _headers);
    final json = jsonDecode(res.body);
    if (json['success'] == true && json['data'] is List) {
      return List<Map<String, dynamic>>.from(json['data']);
    }
    return [];
  }

  Future<void> createBill(Map<String, dynamic> billData) async {
    final uri = Uri.parse('$baseUrl/bills.php?action=create');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(billData));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to create bill');
    }
  }

  Future<void> updateBill(String docId, Map<String, dynamic> updates) async {
    final uri = Uri.parse('$baseUrl/bills.php?action=update');
    final payload = Map<String, dynamic>.from(updates)..['docId'] = docId;
    final res = await http.post(uri, headers: _headers, body: jsonEncode(payload));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update bill');
    }
  }

  // ─── IMAGE UPLOAD ────────────────────────────────────────────────────
  Future<String> uploadImage(Uint8List bytes, String fileName, {String folder = 'products'}) async {
    final uri = Uri.parse('$baseUrl/upload.php');
    final request = http.MultipartRequest('POST', uri);
    request.fields['folder'] = folder;
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

    final streamedResponse = await request.send();
    final res = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(res.body);

    if (res.statusCode == 200 || res.statusCode == 201) {
      return data['data']['url'];
    }
    throw Exception(data['message'] ?? 'Image upload failed');
  }

  // ─── MASTER ITEMS ────────────────────────────────────────────────────
  Future<List<String>> getMasterItems(String type) async {
    final uri = Uri.parse('$baseUrl/masters.php?type=${Uri.encodeComponent(type)}');
    final res = await http.get(uri, headers: _headers);
    final data = jsonDecode(res.body);
    if (data['success'] == true && data['data'] is List) {
      return List<String>.from(data['data']);
    }
    return [];
  }

  Future<void> addMasterItem(String type, String name) async {
    final uri = Uri.parse('$baseUrl/masters.php');
    await http.post(uri, headers: _headers, body: jsonEncode({'type': type, 'name': name}));
  }

  // ─── SETTINGS ────────────────────────────────────────────────────────
  Future<dynamic> getSetting(String key) async {
    final uri = Uri.parse('$baseUrl/settings.php?key=${Uri.encodeComponent(key)}');
    final res = await http.get(uri, headers: _headers);
    final data = jsonDecode(res.body);
    if (data['success'] == true) return data['data'];
    return null;
  }

  Future<void> saveSetting(String key, dynamic value) async {
    final uri = Uri.parse('$baseUrl/settings.php');
    await http.post(uri, headers: _headers, body: jsonEncode({'key': key, 'value': value}));
  }

  // ─── VENDOR ISSUES ───────────────────────────────────────────────────
  Future<void> createVendorIssue(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/vendor_issues.php?action=create');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(data));
    final json = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(json['message'] ?? 'Failed to save vendor issue');
    }
  }

  // ─── AUTH & PASSWORDS ────────────────────────────────────────────────
  Future<void> updateUserPassword(String uid, String newPassword) async {
    final uri = Uri.parse('$baseUrl/auth.php?action=update');
    final res = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'uid': uid,
        'password': newPassword,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(data['message'] ?? 'Failed to update password');
    }
  }

  Future<bool> verifyCurrentPassword(String email, String password) async {
    try {
      final res = await login(email, password);
      return res['user'] != null;
    } catch (_) {
      return false;
    }
  }
}

