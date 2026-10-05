import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final qParams = <String, String>{
    '_t': DateTime.now().millisecondsSinceEpoch.toString(),
  };
  final uri = Uri.parse('https://api.ritumitasrentaljewels.com/bills.php').replace(queryParameters: qParams);
  final res = await http.get(uri);
  final json = jsonDecode(res.body);
  if (json['success'] == true) {
    final bills = json['data'] as List;
    final returnedBillNos = <String>{};
    for (final b in bills) {
      final bType = b['billType'] ?? b['bill_type'] ?? '';
      if (bType.toString().toUpperCase() == 'RETURN') {
        String? orig = b['originalBillNo']?.toString() ?? b['original_bill_no']?.toString();
        if (orig == null || orig.isEmpty) {
          final items = b['items'];
          if (items is List && items.isNotEmpty) {
            for (final item in items) {
              if (item is Map && item['originalBillNo'] != null) {
                orig = item['originalBillNo'].toString();
                break;
              }
            }
          }
        }
        if (orig == null || orig.isEmpty) {
           final narration = b['narration']?.toString() ?? '';
           if (narration.startsWith('Return for ')) {
             orig = narration.replaceAll('Return for ', '').trim();
           }
        }
        if (orig != null && orig.isNotEmpty) {
          returnedBillNos.add(orig.trim().toUpperCase());
        }
      }
    }
    
    for (final hb in bills) {
      final bType = hb['billType'] ?? hb['bill_type'] ?? '';
      if (bType != 'Sale' && bType != 'Advance Payment') continue;
      
      final copy = Map<String, dynamic>.from(hb);
      copy['billNo'] = hb['bill_no'] ?? hb['billNo'] ?? hb['voucherNo'] ?? '';
      
      if (returnedBillNos.contains(copy['billNo'].toString().trim().toUpperCase())) {
        copy['isReturned'] = 1;
        print('${copy['billNo']} isReturned: ${copy['isReturned']}');
      }
    }
  }
}
