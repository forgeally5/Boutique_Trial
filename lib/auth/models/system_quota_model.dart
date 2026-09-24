import 'package:cloud_firestore/cloud_firestore.dart';

class SystemQuotaModel {
  final int maxSalesmen;
  final int currentSalesmen;

  const SystemQuotaModel({
    required this.maxSalesmen,
    required this.currentSalesmen,
  });

  factory SystemQuotaModel.fromMap(Map<String, dynamic> map) {
    return SystemQuotaModel(
      maxSalesmen: map['maxSalesmen'] ?? 0,
      currentSalesmen: map['currentSalesmen'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'maxSalesmen': maxSalesmen,
      'currentSalesmen': currentSalesmen,
    };
  }

  bool get isSalesmanLimitReached => currentSalesmen >= maxSalesmen;
}
