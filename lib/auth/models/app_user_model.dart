import 'package:cloud_firestore/cloud_firestore.dart';

class PermissionsModel {
  // Inventory
  final bool viewInventory;
  final bool addTags;
  final bool editTags;
  final bool deleteTags;
  final bool tagBarcodePrint;
  final bool manageUntaggedStock;
  final bool estimationCalculator;
  final bool dailyCounterStockVerification;

  // Transactions
  final bool salesEntry;
  final bool purchaseEntry;
  final bool serviceEntry;
  final bool cashBankCardReceipts;
  final bool journalEntry;
  final bool deliveryChallan;
  final bool outsourceEntry;
  final bool issueReceipts;
  final bool alterationEntry;
  final bool dailyStockEntry;
  final bool editTransactions;
  final bool deleteTransactions;

  // Master Data
  final bool manageItems;
  final bool manageTax;
  final bool manageRates; // from Rates & Orders

  // Reports
  final bool viewReports;
  final bool viewAuditLog;

  // Admin
  final bool manageUsers;

  const PermissionsModel({
    this.viewInventory = false,
    this.addTags = false,
    this.editTags = false,
    this.deleteTags = false,
    this.tagBarcodePrint = false,
    this.manageUntaggedStock = false,
    this.estimationCalculator = false,
    this.dailyCounterStockVerification = false,
    this.salesEntry = false,
    this.purchaseEntry = false,
    this.serviceEntry = false,
    this.cashBankCardReceipts = false,
    this.journalEntry = false,
    this.deliveryChallan = false,
    this.outsourceEntry = false,
    this.issueReceipts = false,
    this.alterationEntry = false,
    this.dailyStockEntry = false,
    this.editTransactions = false,
    this.deleteTransactions = false,
    this.manageItems = false,
    this.manageTax = false,
    this.manageRates = false,
    this.viewReports = false,
    this.viewAuditLog = false,
    this.manageUsers = false,
  });

  factory PermissionsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PermissionsModel();
    return PermissionsModel(
      viewInventory: map['viewInventory'] ?? false,
      addTags: map['addTags'] ?? false,
      editTags: map['editTags'] ?? false,
      deleteTags: map['deleteTags'] ?? false,
      tagBarcodePrint: map['tagBarcodePrint'] ?? false,
      manageUntaggedStock: map['manageUntaggedStock'] ?? false,
      estimationCalculator: map['estimationCalculator'] ?? false,
      dailyCounterStockVerification: map['dailyCounterStockVerification'] ?? false,
      salesEntry: map['salesEntry'] ?? false,
      purchaseEntry: map['purchaseEntry'] ?? false,
      serviceEntry: map['serviceEntry'] ?? false,
      cashBankCardReceipts: map['cashBankCardReceipts'] ?? false,
      journalEntry: map['journalEntry'] ?? false,
      deliveryChallan: map['deliveryChallan'] ?? false,
      outsourceEntry: map['outsourceEntry'] ?? false,
      issueReceipts: map['issueReceipts'] ?? false,
      alterationEntry: map['alterationEntry'] ?? false,
      dailyStockEntry: map['dailyStockEntry'] ?? false,
      editTransactions: map['editTransactions'] ?? false,
      deleteTransactions: map['deleteTransactions'] ?? false,
      manageItems: map['manageItems'] ?? false,
      manageTax: map['manageTax'] ?? false,
      manageRates: map['manageRates'] ?? false,
      viewReports: map['viewReports'] ?? false,
      viewAuditLog: map['viewAuditLog'] ?? false,
      manageUsers: map['manageUsers'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewInventory': viewInventory,
      'addTags': addTags,
      'editTags': editTags,
      'deleteTags': deleteTags,
      'tagBarcodePrint': tagBarcodePrint,
      'manageUntaggedStock': manageUntaggedStock,
      'estimationCalculator': estimationCalculator,
      'dailyCounterStockVerification': dailyCounterStockVerification,
      'salesEntry': salesEntry,
      'purchaseEntry': purchaseEntry,
      'serviceEntry': serviceEntry,
      'cashBankCardReceipts': cashBankCardReceipts,
      'journalEntry': journalEntry,
      'deliveryChallan': deliveryChallan,
      'outsourceEntry': outsourceEntry,
      'issueReceipts': issueReceipts,
      'alterationEntry': alterationEntry,
      'dailyStockEntry': dailyStockEntry,
      'editTransactions': editTransactions,
      'deleteTransactions': deleteTransactions,
      'manageItems': manageItems,
      'manageTax': manageTax,
      'manageRates': manageRates,
      'viewReports': viewReports,
      'viewAuditLog': viewAuditLog,
      'manageUsers': manageUsers,
    };
  }

  // Presets
  factory PermissionsModel.adminPreset() {
    return const PermissionsModel(
      viewInventory: true, addTags: true, editTags: true, deleteTags: true,
      tagBarcodePrint: true, manageUntaggedStock: true, estimationCalculator: true,
      dailyCounterStockVerification: true, salesEntry: true, purchaseEntry: true,
      serviceEntry: true, cashBankCardReceipts: true, journalEntry: true,
      deliveryChallan: true, outsourceEntry: true, issueReceipts: true,
      alterationEntry: true, dailyStockEntry: true, editTransactions: true,
      deleteTransactions: true, manageItems: true, manageTax: true, manageRates: true,
      viewReports: true, viewAuditLog: true, manageUsers: true,
    );
  }

  factory PermissionsModel.salesmanPreset() {
    return const PermissionsModel(
      viewInventory: true, addTags: false, editTags: false, deleteTags: false,
      tagBarcodePrint: false, manageUntaggedStock: false, estimationCalculator: true,
      dailyCounterStockVerification: true, salesEntry: true, purchaseEntry: false,
      serviceEntry: false, cashBankCardReceipts: false, journalEntry: false,
      deliveryChallan: false, outsourceEntry: false, issueReceipts: false,
      alterationEntry: false, dailyStockEntry: false, editTransactions: false,
      deleteTransactions: false, manageItems: false, manageTax: false, manageRates: false,
      viewReports: false, viewAuditLog: false, manageUsers: false,
    );
  }
}

class AppUserModel {
  final String uid;
  final String email;
  final String displayName;
  final String role; // 'admin', 'salesman'
  final bool isActive;
  final double maxDiscountPercent;
  final PermissionsModel permissions;
  final DateTime? createdAt;

  const AppUserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.maxDiscountPercent,
    required this.permissions,
    this.createdAt,
  });

  factory AppUserModel.fromMap(Map<String, dynamic> map, String id) {
    return AppUserModel(
      uid: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'salesman',
      isActive: map['isActive'] ?? false,
      maxDiscountPercent: (map['maxDiscountPercent'] ?? 0.0).toDouble(),
      permissions: PermissionsModel.fromMap(map['permissions']),
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      'isActive': isActive,
      'maxDiscountPercent': maxDiscountPercent,
      'permissions': permissions.toMap(),
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isSalesman => role.toLowerCase() == 'salesman';
}
