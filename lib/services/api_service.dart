import 'dart:convert';
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
    try {
      final res = await http.post(
        url,
        headers: _headers,
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      debugPrint('[ApiService] Login response (${res.statusCode}): ${res.body}');

      Map<String, dynamic> data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        throw Exception('Server returned invalid response. Please try again.');
      }

      if (res.statusCode == 200 && data['success'] == true) {
        _authToken = data['data']?['token']?.toString();
        return Map<String, dynamic>.from(data['data'] as Map? ?? {});
      }
      throw Exception(data['message']?.toString() ?? 'Login failed (${res.statusCode})');
    } on Exception catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Connection timed out. Please check your internet connection.');
      }
      rethrow;
    }
  }

  Future<String> forgotPassword(String email) async {
    final url = Uri.parse('$baseUrl/auth.php?action=forgot_password');
    final res = await http.post(
      url,
      headers: _headers,
      body: jsonEncode({
        'action': 'forgot_password',
        'email': email.trim(),
      }),
    ).timeout(const Duration(seconds: 15));

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      return data['message']?.toString() ?? 'If this email is registered, instructions have been sent.';
    }
    throw Exception(data['message']?.toString() ?? 'Password reset request failed (${res.statusCode})');
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

  Future<void> updateUser(Map<String, dynamic> userData) async {
    final url = Uri.parse('$baseUrl/auth.php?action=update');
    final res = await http.post(url, headers: _headers, body: jsonEncode(userData));
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to update user');
    }
  }

  Future<void> deleteUser(String uid) async {
    final url = Uri.parse('$baseUrl/auth.php?action=delete&uid=${Uri.encodeComponent(uid)}');
    final res = await http.post(url, headers: _headers);
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete user');
    }
  }

  // ─── PRODUCTS ────────────────────────────────────────────────────────
  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

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
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 20));
    final json = jsonDecode(res.body);

    debugPrint('[ApiService] getProducts response: success=${json['success']}, count=${(json['data'] as List?)?.length ?? 0}');

    if (json['success'] == true && json['data'] is List) {
      return (json['data'] as List).map((map) {
        return Product(
          tagId: map['tag_id']?.toString() ?? '',
          name: map['name']?.toString() ?? '',
          category: map['category']?.toString() ?? '',
          deity: map['deity']?.toString() ?? '',
          material: map['material']?.toString() ?? '',
          size: map['size']?.toString() ?? '',
          status: map['status']?.toString() ?? 'In Stock',
          vendor: map['vendor']?.toString() ?? '',
          notes: map['notes']?.toString() ?? '',
          pricingType: map['pricing_type']?.toString() ?? 'Quantity-Based',
          grossWeight: _toDouble(map['gross_weight']),
          netWeight: _toDouble(map['net_weight']),
          weightUnit: map['weight_unit']?.toString() ?? 'g',
          ratePerGram: _toDouble(map['rate_per_gram']),
          makingCharges: _toDouble(map['making_charges']),
          quantity: _toInt(map['quantity']),
          issueQuantity: _toInt(map['issue_quantity']),
          reservedQuantity: _toInt(map['reserved_quantity']),
          unit: map['unit']?.toString() ?? 'piece',
          mrp: _toDouble(map['mrp']),
          sellingPrice: _toDouble(map['selling_price']),
          discountValue: _toDouble(map['discount_value']),
          discountType: map['discount_type']?.toString() ?? '%',
          finalPrice: _toDouble(map['final_price']),
          gstRate: _toDouble(map['gst_rate']),
          isFestivalStock: map['is_festival_stock'] == 1 || map['is_festival_stock'] == true,
          isReserved: map['is_reserved'] == 1 || map['is_reserved'] == true,
          reservedFor: map['reserved_for']?.toString() ?? '',
          imageUrl: map['image_url']?.toString() ?? '',
          rawJson: (map['raw_json'] is Map<String, dynamic>)
              ? map['raw_json'] as Map<String, dynamic>
              : map is Map<String, dynamic>
                  ? map
                  : {},
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
  static Map<String, dynamic> _normalizeBill(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    dynamic parseJson(dynamic val) {
      if (val is String) {
        try {
          return jsonDecode(val);
        } catch (_) {
          return val;
        }
      }
      return val;
    }

    final items = parseJson(map['items']);
    final payments = parseJson(map['payments']);
    final paymentHistory = parseJson(map['payment_history'] ?? map['paymentHistory']);
    final customCustomerDetails = parseJson(map['custom_customer_details'] ?? map['customCustomerDetails']);

    final totalPayable = _toDouble(map['total_payable'] ?? map['totalPayable']);
    final amountReceived = _toDouble(map['amount_received'] ?? map['amountReceived']);
    final pendingBalance = _toDouble(map['pending_balance'] ?? map['pendingBalance']);
    final subtotal = _toDouble(map['subtotal']);
    final taxAmount = _toDouble(map['tax_amount'] ?? map['taxAmount']);
    final adjustmentAmount = _toDouble(map['adjustment_amount'] ?? map['adjustmentAmount']);
    final extraDiscountAmount = _toDouble(map['extra_discount_amount'] ?? map['extraDiscountAmount']);
    final extraDiscountValue = _toDouble(map['extra_discount_value'] ?? map['extraDiscountValue']);
    final gstPercent = _toDouble(map['gst_percent'] ?? map['gstPercent']);
    final balanceReturned = _toDouble(map['balance_returned'] ?? map['balanceReturned']);

    final docId = map['doc_id']?.toString() ?? map['docId']?.toString() ?? map['id']?.toString() ?? '';
    final billNo = map['bill_no']?.toString() ?? map['billNo']?.toString() ?? map['voucherNo']?.toString() ?? '';
    final billType = map['bill_type']?.toString() ?? map['billType']?.toString() ?? 'Sale';
    final billDate = map['bill_date'] ?? map['billDate'] ?? map['voucherDate'] ?? map['createdAt'];
    String customerName = map['customer_name']?.toString() ?? map['customerName']?.toString() ?? map['acName']?.toString() ?? 'Walk-in Customer';
    String customerMobile = map['customer_mobile']?.toString() ?? map['customerMobile']?.toString() ?? map['phone']?.toString() ?? '';
    String customerAddress = map['customer_address']?.toString() ?? map['customerAddress']?.toString() ?? '';
    String narrationText = map['narration']?.toString() ?? '';

    // Check if narration has encoded customer details
    final rawNarration = map['narration']?.toString() ?? '';
    if (rawNarration.trim().startsWith('{') && rawNarration.trim().endsWith('}')) {
      try {
        final parsedNarration = jsonDecode(rawNarration);
        if (parsedNarration is Map) {
          if (parsedNarration['customerName'] != null || parsedNarration['custom_name'] != null) {
            customerName = (parsedNarration['customerName'] ?? parsedNarration['custom_name']).toString();
          }
          if (parsedNarration['customerMobile'] != null || parsedNarration['custom_mobile'] != null) {
            customerMobile = (parsedNarration['customerMobile'] ?? parsedNarration['custom_mobile']).toString();
          }
          if (parsedNarration['customerAddress'] != null || parsedNarration['custom_address'] != null) {
            customerAddress = (parsedNarration['customerAddress'] ?? parsedNarration['custom_address']).toString();
          }
          narrationText = parsedNarration['note']?.toString() ?? '';
        }
      } catch (_) {}
    }

    final paymentMode = map['payment_mode']?.toString() ?? map['paymentMode']?.toString() ?? 'Cash';
    final paymentStatus = map['payment_status']?.toString() ?? map['paymentStatus']?.toString() ?? (pendingBalance <= 0 ? 'Paid' : 'Partial');
    final isFullyPaid = map['is_fully_paid'] == 1 || map['is_fully_paid'] == true || map['isFullyPaid'] == true || pendingBalance <= 0;

    final returnReason = map['return_reason']?.toString() ?? map['returnReason']?.toString() ?? narrationText;
    final returnStatus = map['return_status']?.toString() ?? map['returnStatus']?.toString() ?? 'Processed';
    final originalBillNo = map['original_bill_no']?.toString() ?? map['originalBillNo']?.toString() ?? '';

    return {
      ...map,
      'docId': docId,
      '_docId': docId,
      'id': docId,
      'billNo': billNo,
      'voucherNo': billNo,
      'billType': billType,
      'billDate': billDate,
      'voucherDate': billDate,
      'customerName': customerName,
      'acName': customerName,
      'customerMobile': customerMobile,
      'phone': customerMobile,
      'customerAddress': customerAddress,
      'totalPayable': totalPayable,
      'amountReceived': amountReceived,
      'pendingBalance': pendingBalance,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'adjustmentAmount': adjustmentAmount,
      'extraDiscountAmount': extraDiscountAmount,
      'extraDiscountValue': extraDiscountValue,
      'extraDiscountType': map['extra_discount_type'] ?? map['extraDiscountType'] ?? '%',
      'gstPercent': gstPercent,
      'balanceReturned': balanceReturned,
      'paymentMode': paymentMode,
      'paymentStatus': paymentStatus,
      'isFullyPaid': isFullyPaid,
      'narration': narrationText,
      'returnReason': returnReason,
      'return_reason': returnReason,
      'returnStatus': returnStatus,
      'return_status': returnStatus,
      'originalBillNo': originalBillNo,
      'original_bill_no': originalBillNo,
      'items': items is List ? items : [],
      'payments': payments is List ? payments : [],
      'paymentHistory': paymentHistory is List ? paymentHistory : [],
      'customCustomerDetails': customCustomerDetails is Map ? customCustomerDetails : {},
      'total_payable': totalPayable,
      'amount_received': amountReceived,
      'pending_balance': pendingBalance,
      'bill_no': billNo,
      'bill_type': billType,
      'bill_date': billDate,
      'customer_name': customerName,
      'customer_mobile': customerMobile,
      'payment_mode': paymentMode,
      'payment_status': paymentStatus,
      'is_fully_paid': isFullyPaid,
    };
  }

  // ─── BILLING ─────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBills({
    String? customer,
    bool pendingOnly = false,
    String? startDate,
    String? endDate,
  }) async {
    final qParams = <String, String>{
      '_t': DateTime.now().millisecondsSinceEpoch.toString(), // Prevent browser caching on Web
    };
    if (customer != null && customer.isNotEmpty) qParams['customer'] = customer;
    if (pendingOnly) qParams['pendingOnly'] = 'true';
    if (startDate != null) qParams['startDate'] = startDate;
    if (endDate != null) qParams['endDate'] = endDate;

    final uri = Uri.parse('$baseUrl/bills.php').replace(queryParameters: qParams);
    final res = await http.get(uri, headers: _headers);
    final json = jsonDecode(res.body);
    if (json['success'] == true && json['data'] is List) {
      return (json['data'] as List)
          .map((e) => _normalizeBill(Map<String, dynamic>.from(e as Map)))
          .toList();
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

  Future<void> deleteBill(String docId) async {
    final uri = Uri.parse('$baseUrl/bills.php?action=delete&docId=${Uri.encodeComponent(docId)}');
    final res = await http.post(uri, headers: _headers);
    final data = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Failed to delete bill');
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

  Future<void> deleteMasterItem(String type, String name) async {
    final uri = Uri.parse('$baseUrl/masters.php?action=delete&type=${Uri.encodeComponent(type)}&name=${Uri.encodeComponent(name)}');
    await http.post(uri, headers: _headers);
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

  Future<void> createVendorIssue(Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/vendor_issues.php?action=create');
    final res = await http.post(uri, headers: _headers, body: jsonEncode(data));
    final json = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception(json['message'] ?? 'Failed to save vendor issue');
    }
  }

  static Map<String, dynamic> _normalizeVendorIssue(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);

    dynamic parseJson(dynamic val) {
      if (val is String) {
        try {
          return jsonDecode(val);
        } catch (_) {
          return val;
        }
      }
      return val;
    }

    final items = parseJson(map['items']);
    final docId = map['doc_id']?.toString() ?? map['id']?.toString() ?? '';
    final vendor = map['vendor_name']?.toString() ?? map['vendor']?.toString() ?? '—';
    final status = map['status']?.toString() ?? map['actionTaken']?.toString() ?? map['action_taken']?.toString() ?? 'Pending';
    final issueDate = map['issue_date'] ?? map['dateReported'] ?? map['date_reported'] ?? map['created_at'];
    double refundAmount = _toDouble(map['total_amount'] ?? map['refundAmount'] ?? map['refund_amount']);
    if (refundAmount <= 0.0 && items is List && items.isNotEmpty) {
      refundAmount = items.fold(
          0.0,
          (sum, it) =>
              sum +
              _toDouble(it is Map
                  ? (it['amount'] ?? it['lineAmount'] ?? it['refundAmount'])
                  : 0));
    }
    final tagId = map['tagId']?.toString() ??
        map['tag_id']?.toString() ??
        (items is List && items.isNotEmpty
            ? items.first['tagId']?.toString() ?? ''
            : '');
    final productName = map['productName']?.toString() ??
        map['product_name']?.toString() ??
        (items is List && items.isNotEmpty
            ? (items.first['productName'] ?? items.first['name'])?.toString() ??
                ''
            : '');
    final qty = _toInt(map['quantity'] ??
        (items is List && items.isNotEmpty
            ? items.first['qty'] ?? items.first['quantity'] ?? 1
            : 1));
    final issueType = map['issueType']?.toString() ??
        map['issue_type']?.toString() ??
        (items is List && items.isNotEmpty
            ? items.first['issueType']?.toString() ?? 'Damaged'
            : 'Damaged');

    return {
      ...map,
      'id': docId,
      'docId': docId,
      '_docId': docId,
      'vendor': vendor,
      'vendorName': vendor,
      'status': status,
      'actionTaken': status,
      'dateReported': issueDate,
      'issueDate': issueDate,
      'refundAmount': refundAmount,
      'tagId': tagId,
      'productName': productName,
      'quantity': qty,
      'qty': qty,
      'issueType': issueType,
      'notes': map['notes']?.toString() ?? '',
      'items': items is List ? items : [],
    };
  }


  Future<List<Map<String, dynamic>>> getVendorIssues() async {
    final uri = Uri.parse('$baseUrl/vendor_issues.php');
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 15));
    final json = jsonDecode(res.body);
    if (json['success'] == true && json['data'] is List) {
      return (json['data'] as List)
          .map((e) => _normalizeVendorIssue(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    return [];
  }

  Future<void> updateVendorIssue(String id, Map<String, dynamic> data) async {
    final uri = Uri.parse('$baseUrl/vendor_issues.php?action=update');
    final payload = Map<String, dynamic>.from(data)..['id'] = id;
    final res = await http.post(uri, headers: _headers, body: jsonEncode(payload));
    final json = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(json['message'] ?? 'Failed to update vendor issue');
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

